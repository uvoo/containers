package main

import (
    "bytes"
    "context"
    "crypto/tls"
    "fmt"
    "io"
    "net/http"
    "net/url"
    "os"
    "os/signal"
    "path"
    "strings"
    "sync"
    "syscall"
    "time"

    "github.com/labstack/echo/v4"
    "github.com/labstack/echo/v4/middleware"

    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
    "github.com/sirupsen/logrus"
    "golang.org/x/crypto/bcrypt"
    "gorm.io/driver/postgres"
    "gorm.io/gorm"
)

var (
    db         *gorm.DB
    mimirURL   *url.URL
    mimirUser  string
    mimirPass  string
    httpClient *http.Client
    log        = logrus.New()

    userCache = make(map[string]User)
    cacheMux  = &sync.RWMutex{}
    cacheTTL  = 30 * time.Second

    adminUser string
    adminPass string

    requestCounter = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "proxy_requests_total",
            Help: "Total proxied requests",
        },
        []string{"path", "method", "status"},
    )

    requestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "proxy_request_duration_seconds",
            Help:    "Duration of proxied requests",
            Buckets: prometheus.DefBuckets,
        },
        []string{"path"},
    )
)

type User struct {
    Username      string    `gorm:"primaryKey"`
    Password1     string
    Password2     string
    OrgID         string
    LastLogin     time.Time
    LastLoginIP   string
    FailedLogins  int
    LastFailedIP  string
}

func main() {
    initLogger()
    validateEnvVars("MIMIR_URL", "MIMIR_USERNAME", "MIMIR_PASSWORD")
    openDB()

    adminUser = os.Getenv("ADMIN_USERNAME")
    adminPass = os.Getenv("ADMIN_PASSWORD")

    var err error
    mimirURL, err = url.Parse(os.Getenv("MIMIR_URL"))
    if err != nil {
        log.WithError(err).Fatal("Invalid MIMIR_URL")
    }
    mimirUser = os.Getenv("MIMIR_USERNAME")
    mimirPass = os.Getenv("MIMIR_PASSWORD")

    if os.Getenv("BACKEND_SKIP_TLS_VERIFY") == "true" {
        log.Warn("BACKEND_SKIP_TLS_VERIFY is true — skipping TLS verification for backend requests!")
        httpClient = &http.Client{
            Timeout: 30 * time.Second,
            Transport: &http.Transport{
                TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
            },
        }
    } else {
        httpClient = &http.Client{Timeout: 30 * time.Second}
    }

    loadUserCache()
    go cacheRefresher()

    prometheus.MustRegister(requestCounter)
    prometheus.MustRegister(requestDuration)

    e := echo.New()
    e.HideBanner = true
    e.Use(middleware.Recover())
    e.Use(middleware.Logger())

    // health & metrics
    e.GET("/healthz", func(c echo.Context) error { return c.String(http.StatusOK, "ok") })
    e.GET("/metrics", echo.WrapHandler(promhttp.Handler()))
    e.GET("/version", func(c echo.Context) error {
        version := os.Getenv("VERSION")
        if version == "" {
            version = "unknown"
        }
        return c.String(http.StatusOK, fmt.Sprintf("mimirproxy version: %s\n", version))
    })

    // admin endpoints
    admin := e.Group("/admin", adminAuth)
    admin.GET("/refresh", adminRefresh)
    admin.GET("/stats", adminStats)
    admin.POST("/users", adminAddUser)
    admin.DELETE("/users", adminDeleteUser)

    // proxy endpoints
    for _, p := range getAllowedPaths() {
        e.Any(p, handleProxy)
    }

    // graceful shutdown
    go func() {
        if err := e.Start(":8080"); err != nil && err != http.ErrServerClosed {
            log.WithError(err).Fatal("server error")
        }
    }()

    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    if err := e.Shutdown(ctx); err != nil {
        log.WithError(err).Fatal("forced shutdown")
    }
    log.Info("Server stopped")
}

func getAllowedPaths() []string {
    env := os.Getenv("ALLOWED_PATHS")
    if env != "" {
        parts := strings.Split(env, ",")
        for i := range parts {
            parts[i] = strings.TrimSpace(parts[i])
        }
        return parts
    }
    return []string{
        "/prometheus/*",
        "/api/v1/*",
        "/otlp/v1/metrics",
        "/distributor",
        "/prometheus/api/v1/rules",
        "/prometheus/api/v1/alerts",
        "/prometheus/config/v1/rules",
        "/api/v1/status/buildinfo",
    }
}

func handleProxy(c echo.Context) error {
    start := time.Now()
    if !authenticate(c.Request()) {
        requestCounter.WithLabelValues(c.Path(), c.Request().Method, "401").Inc()
        return echo.NewHTTPError(http.StatusUnauthorized)
    }

    username, _, _ := c.Request().BasicAuth()
    orgID := userCache[username].OrgID

    backendURL := *mimirURL
    backendURL.Path = path.Join(mimirURL.Path, c.Request().URL.Path)
    backendURL.RawQuery = c.Request().URL.RawQuery

    var body io.Reader
    if c.Request().Body != nil {
        data, err := io.ReadAll(c.Request().Body)
        if err != nil {
            requestCounter.WithLabelValues(c.Path(), c.Request().Method, "500").Inc()
            return echo.NewHTTPError(http.StatusInternalServerError)
        }
        body = bytes.NewReader(data)
        defer c.Request().Body.Close()
    }

    req, err := http.NewRequestWithContext(c.Request().Context(), c.Request().Method, backendURL.String(), body)
    if err != nil {
        requestCounter.WithLabelValues(c.Path(), c.Request().Method, "500").Inc()
        return echo.NewHTTPError(http.StatusInternalServerError)
    }
    req.Header = c.Request().Header.Clone()
    req.SetBasicAuth(mimirUser, mimirPass)
    if orgID != "" {
        req.Header.Set("X-Scope-OrgID", orgID)
    }

    resp, err := httpClient.Do(req)
    if err != nil {
        requestCounter.WithLabelValues(c.Path(), c.Request().Method, "502").Inc()
        return echo.NewHTTPError(http.StatusBadGateway)
    }
    defer resp.Body.Close()

    statusCode := resp.StatusCode
    requestCounter.WithLabelValues(c.Path(), c.Request().Method, fmt.Sprintf("%d", statusCode)).Inc()
    requestDuration.WithLabelValues(c.Path()).Observe(time.Since(start).Seconds())

    c.Response().WriteHeader(resp.StatusCode)
    io.Copy(c.Response(), resp.Body)

    log.WithFields(logrus.Fields{
        "path":     c.Path(),
        "method":   c.Request().Method,
        "status":   resp.StatusCode,
        "duration": time.Since(start),
    }).Info("proxied request")

    return nil
}

func adminRefresh(c echo.Context) error {
    loadUserCache()
    cacheMux.RLock()
    defer cacheMux.RUnlock()

    var buf strings.Builder
    buf.WriteString("Current cached users:\n")
    for u, data := range userCache {
        buf.WriteString(fmt.Sprintf("- %s (org_id: %s)\n", u, data.OrgID))
    }
    return c.String(http.StatusOK, buf.String())
}

func adminStats(c echo.Context) error {
    var users []User
    if err := db.Find(&users).Error; err != nil {
        return echo.NewHTTPError(http.StatusInternalServerError, "Failed to load users")
    }

    var buf strings.Builder
    buf.WriteString("=== Mimir Proxy Stats ===\n")
    buf.WriteString(fmt.Sprintf("Total Users: %d\n\n", len(users)))
    buf.WriteString(fmt.Sprintf("%-20s %-20s %-20s %-10s\n", "Username", "OrgID", "LastLogin", "FailedLogins"))
    for _, u := range users {
        buf.WriteString(fmt.Sprintf("%-20s %-20s %-20s %-10d\n",
            u.Username, u.OrgID, u.LastLogin.Format(time.RFC3339), u.FailedLogins))
    }
    return c.String(http.StatusOK, buf.String())
}

func adminAddUser(c echo.Context) error {
    username := c.FormValue("username")
    password := c.FormValue("password")
    orgID := c.FormValue("org_id")
    which := c.FormValue("which")

    if username == "" || password == "" {
        return echo.NewHTTPError(http.StatusBadRequest, "username & password required")
    }

    hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
    if err != nil {
        return echo.NewHTTPError(http.StatusInternalServerError, "bcrypt error")
    }

    var u User
    db.First(&u, "username = ?", username)

    if u.Username == "" {
        u.Username = username
        u.OrgID = orgID
    }

    if which == "2" {
        u.Password2 = string(hash)
    } else {
        u.Password1 = string(hash)
    }

    if err := db.WithContext(c.Request().Context()).Save(&u).Error; err != nil {
        return echo.NewHTTPError(http.StatusInternalServerError, "Failed to save user")
    }

    loadUserCache()
    return c.String(http.StatusOK, fmt.Sprintf("Added/Updated user: %s\n", username))
}

func adminDeleteUser(c echo.Context) error {
    username := c.FormValue("username")
    if username == "" {
        return echo.NewHTTPError(http.StatusBadRequest, "username required")
    }

    if err := db.WithContext(c.Request().Context()).Delete(&User{}, "username = ?", username).Error; err != nil {
        return echo.NewHTTPError(http.StatusInternalServerError, "Failed to delete user")
    }

    loadUserCache()
    return c.String(http.StatusOK, fmt.Sprintf("Deleted user: %s\n", username))
}

func adminAuth(next echo.HandlerFunc) echo.HandlerFunc {
    return func(c echo.Context) error {
        username, password, ok := c.Request().BasicAuth()
        if !ok || username != adminUser || password != adminPass {
            return echo.NewHTTPError(http.StatusUnauthorized)
        }
        return next(c)
    }
}

func authenticate(r *http.Request) bool {
    username, password, ok := r.BasicAuth()
    if !ok {
        return false
    }
    ip := getClientIP(r)
    return validateUser(username, password, ip)
}

func getClientIP(r *http.Request) string {
    xForwardedFor := r.Header.Get("X-Forwarded-For")
    if xForwardedFor != "" {
        parts := strings.Split(xForwardedFor, ",")
        return strings.TrimSpace(parts[0])
    }
    ip := strings.Split(r.RemoteAddr, ":")[0]
    return ip
}

func validateUser(username, password, ip string) bool {
    cacheMux.RLock()
    u, ok := userCache[username]
    cacheMux.RUnlock()

    if !ok {
        incrementFailed(username, ip)
        return false
    }

    if bcrypt.CompareHashAndPassword([]byte(u.Password1), []byte(password)) == nil ||
        (u.Password2 != "" && bcrypt.CompareHashAndPassword([]byte(u.Password2), []byte(password)) == nil) {
        updateLastLogin(username, ip)
        return true
    }

    incrementFailed(username, ip)
    return false
}

func incrementFailed(username, ip string) {
    db.Model(&User{}).Where("username = ?", username).Updates(map[string]interface{}{
        "failed_logins":  gorm.Expr("failed_logins + 1"),
        "last_failed_ip": ip,
    })
}

func updateLastLogin(username, ip string) {
    db.Model(&User{}).Where("username = ?", username).Updates(map[string]interface{}{
        "last_login":    time.Now(),
        "failed_logins": 0,
        "last_login_ip": ip,
    })
}

func cacheRefresher() {
    for {
        time.Sleep(cacheTTL)
        loadUserCache()
    }
}

func loadUserCache() {
    var users []User
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    if err := db.WithContext(ctx).Find(&users).Error; err != nil {
        log.WithError(err).Error("Failed to load users")
        return
    }

    tmp := make(map[string]User)
    for _, u := range users {
        tmp[u.Username] = u
    }

    cacheMux.Lock()
    userCache = tmp
    cacheMux.Unlock()
    log.WithField("count", len(userCache)).Info("User cache refreshed")
}

func initLogger() {
    levelStr := strings.ToLower(os.Getenv("LOG_LEVEL"))
    if levelStr == "" {
        levelStr = "info"
    }
    level, err := logrus.ParseLevel(levelStr)
    if err != nil {
        level = logrus.InfoLevel
    }
    log.SetLevel(level)
    log.SetFormatter(&logrus.JSONFormatter{TimestampFormat: time.RFC3339})
    log.SetOutput(os.Stdout)
}

func validateEnvVars(vars ...string) {
    for _, v := range vars {
        if os.Getenv(v) == "" {
            log.WithField("var", v).Fatal("Environment variable must be set")
        }
    }
}

func openDB() {
    dsn := fmt.Sprintf(
        "host=%s port=%s dbname=%s user=%s password=%s sslmode=disable",
        os.Getenv("POSTGRES_HOST"), os.Getenv("POSTGRES_PORT"),
        os.Getenv("POSTGRES_DB"), os.Getenv("POSTGRES_USER"), os.Getenv("POSTGRES_PASSWORD"),
    )
    var err error
    db, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
    if err != nil {
        log.WithError(err).Fatal("Failed to connect to Postgres")
    }
    if err := db.AutoMigrate(&User{}); err != nil {
        log.WithError(err).Fatal("Failed to migrate schema")
    }
    log.Info("Connected to Postgres and ensured schema")
}
