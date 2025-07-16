package main

import (
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

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/prometheus/client_golang/prometheus/promauto"
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

	requestCounter = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "proxy_requests_total",
			Help: "Total proxied requests",
		},
		[]string{"path", "method", "status"},
	)

	requestDuration = promauto.NewHistogramVec(
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

	mux := http.NewServeMux()
	registerProxyRoutes(mux)

	mux.HandleFunc("/admin/refresh", adminAuth(handleAdminRefresh))
	mux.HandleFunc("/admin/users", adminAuth(handleAdminUsers))
	mux.HandleFunc("/admin/stats", adminAuth(handleAdminStats))
	mux.Handle("/metrics", promhttp.Handler())
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})
	mux.HandleFunc("/version", handleVersion)

	srv := &http.Server{Addr: ":8080", Handler: mux}

	go func() {
		log.WithField("addr", srv.Addr).Info("HTTP server running")
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.WithError(err).Fatal("HTTP server error")
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop
	log.Info("Shutting down gracefully...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.WithError(err).Fatal("Server forced to shutdown")
	}
	log.Info("Server stopped.")
}

func cacheRefresher() {
	for {
		time.Sleep(cacheTTL)
		loadUserCache()
	}
}

func loadUserCache() {
	log.Info("Loading user cache...")
	var users []User
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := db.WithContext(ctx).Find(&users).Error; err != nil {
		log.WithError(err).Error("Failed to load users from DB")
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

func validateUser(username, password string, ip string) bool {
	cacheMux.RLock()
	u, ok := userCache[username]
	cacheMux.RUnlock()

	if !ok {
		log.WithField("user", username).Warn("User not found in cache")
		incrementFailed(username, ip)
		return false
	}

	if bcrypt.CompareHashAndPassword([]byte(u.Password1), []byte(password)) == nil {
		updateLastLogin(username, ip)
		return true
	}

	if u.Password2 != "" && bcrypt.CompareHashAndPassword([]byte(u.Password2), []byte(password)) == nil {
		updateLastLogin(username, ip)
		return true
	}

	log.WithField("user", username).Warn("Password mismatch")
	incrementFailed(username, ip)
	return false
}

func incrementFailed(username string, ip string) {
	db.Model(&User{}).Where("username = ?", username).Updates(map[string]interface{}{
		"failed_logins":  gorm.Expr("failed_logins + 1"),
		"last_failed_ip": ip,
	})
}

func updateLastLogin(username string, ip string) {
	db.Model(&User{}).Where("username = ?", username).Updates(map[string]interface{}{
		"last_login":    time.Now(),
		"failed_logins": 0,
		"last_login_ip": ip,
	})
}

func registerProxyRoutes(mux *http.ServeMux) {
	paths := getAllowedPaths()
	for _, p := range paths {
		mux.HandleFunc(p, handleProxy)
	}
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
		"/prometheus/",
		"/api/v1/push",
		"/otlp/v1/metrics",
		"/distributor",
		"/prometheus/api/v1/rules",
		"/prometheus/api/v1/alerts",
		"/prometheus/config/v1/rules",
		"/api/v1/status/buildinfo",
	}
}

func handleProxy(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	if !authenticate(r) {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		requestCounter.WithLabelValues(r.URL.Path, r.Method, "401").Inc()
		return
	}

	username, _, _ := r.BasicAuth()
	orgID := userCache[username].OrgID

	backendURL := *mimirURL
	backendURL.Path = path.Join(mimirURL.Path, r.URL.Path)
	backendURL.RawQuery = r.URL.RawQuery

	var body io.Reader
	if r.Body != nil {
		data, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "Failed to read request body", http.StatusInternalServerError)
			requestCounter.WithLabelValues(r.URL.Path, r.Method, "500").Inc()
			return
		}
		defer r.Body.Close()
		body = strings.NewReader(string(data))
	}

	backendReq, err := http.NewRequestWithContext(r.Context(), r.Method, backendURL.String(), body)
	if err != nil {
		http.Error(w, "Failed to create backend request", http.StatusInternalServerError)
		log.WithError(err).Error("creating backend request")
		requestCounter.WithLabelValues(r.URL.Path, r.Method, "500").Inc()
		return
	}

	backendReq.Header = r.Header.Clone()
	backendReq.SetBasicAuth(mimirUser, mimirPass)

	if orgID != "" {
		backendReq.Header.Set("X-Scope-OrgID", orgID)
	}

	resp, err := httpClient.Do(backendReq)
	if err != nil {
		http.Error(w, "Failed to reach backend", http.StatusBadGateway)
		log.WithError(err).Error("querying Mimir")
		requestCounter.WithLabelValues(r.URL.Path, r.Method, "502").Inc()
		return
	}
	defer resp.Body.Close()

	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)

	statusCode := fmt.Sprintf("%d", resp.StatusCode)
	requestCounter.WithLabelValues(r.URL.Path, r.Method, statusCode).Inc()
	requestDuration.WithLabelValues(r.URL.Path).Observe(time.Since(start).Seconds())

	log.WithFields(logrus.Fields{
		"path":     r.URL.Path,
		"method":   r.Method,
		"status":   resp.StatusCode,
		"duration": time.Since(start),
	}).Info("proxied request")
}

func handleAdminRefresh(w http.ResponseWriter, r *http.Request) {
	loadUserCache()
	cacheMux.RLock()
	defer cacheMux.RUnlock()

	fmt.Fprintf(w, "Current cached users:\n")
	for u, data := range userCache {
		fmt.Fprintf(w, "- %s (org_id: %s)\n", u, data.OrgID)
	}
}

func handleAdminStats(w http.ResponseWriter, r *http.Request) {
	var users []User
	if err := db.Find(&users).Error; err != nil {
		http.Error(w, "Failed to load users", http.StatusInternalServerError)
		return
	}

	fmt.Fprintf(w, "=== Mimir Proxy Stats ===\n")
	fmt.Fprintf(w, "Total Users: %d\n", len(users))
	fmt.Fprintf(w, "\n%-20s %-20s %-20s %-10s\n", "Username", "OrgID", "LastLogin", "FailedLogins")
	for _, u := range users {
		fmt.Fprintf(w, "%-20s %-20s %-20s %-10d\n",
			u.Username, u.OrgID, u.LastLogin.Format(time.RFC3339), u.FailedLogins)
	}
}

func handleAdminUsers(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "POST":
		username := r.FormValue("username")
		password := r.FormValue("password")
		orgID := r.FormValue("org_id")
		which := r.FormValue("which")

		if username == "" || password == "" {
			http.Error(w, "username & password required", http.StatusBadRequest)
			return
		}

		hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, "bcrypt error", http.StatusInternalServerError)
			return
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

		if err := db.WithContext(r.Context()).Save(&u).Error; err != nil {
			http.Error(w, "Failed to save user", http.StatusInternalServerError)
			return
		}

		loadUserCache()
		fmt.Fprintf(w, "Added/Updated user: %s\n", username)

	case "DELETE":
		username := r.FormValue("username")
		if username == "" {
			http.Error(w, "username required", http.StatusBadRequest)
			return
		}

		if err := db.WithContext(r.Context()).Delete(&User{}, "username = ?", username).Error; err != nil {
			http.Error(w, "Failed to delete user", http.StatusInternalServerError)
			return
		}

		loadUserCache()
		fmt.Fprintf(w, "Deleted user: %s\n", username)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func adminAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if adminUser == "" || adminPass == "" {
			http.Error(w, "Admin not configured", http.StatusForbidden)
			return
		}

		username, password, ok := r.BasicAuth()
		if !ok || username != adminUser || password != adminPass {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		next.ServeHTTP(w, r)
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

func handleVersion(w http.ResponseWriter, r *http.Request) {
	version := os.Getenv("VERSION")
	if version == "" {
		version = "unknown"
	}
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf("mimirproxy version: %s\n", version)))
}

