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
)

type User struct {
	Username  string `gorm:"primaryKey"`
	Password1 string
	Password2 string
	OrgID     string
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

	if ttlStr := os.Getenv("USER_CACHE_TTL"); ttlStr != "" {
		if d, err := time.ParseDuration(ttlStr); err == nil {
			cacheTTL = d
		}
	}

	loadUserCache()
	go cacheRefresher()

	mux := http.NewServeMux()
	mux.HandleFunc("/prometheus/", handlePrometheusQuery)
	mux.HandleFunc("/api/v1/push", handlePush)
	mux.HandleFunc("/admin/refresh", adminAuth(handleAdminRefresh))
	mux.HandleFunc("/admin/users", adminAuth(handleAdminUsers))
	mux.Handle("/metrics", promhttp.Handler())
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

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

func validateUser(username, password string) bool {
	cacheMux.RLock()
	defer cacheMux.RUnlock()
	u, ok := userCache[username]
	if !ok {
		log.WithField("user", username).Warn("User not found in cache")
		return false
	}

	if bcrypt.CompareHashAndPassword([]byte(u.Password1), []byte(password)) == nil {
		return true
	}

	if u.Password2 != "" && bcrypt.CompareHashAndPassword([]byte(u.Password2), []byte(password)) == nil {
		return true
	}

	log.WithField("user", username).Warn("Password mismatch")
	return false
}

func handlePrometheusQuery(w http.ResponseWriter, r *http.Request) {
	if !authenticate(r) {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	username, _, _ := r.BasicAuth()
	orgID := userCache[username].OrgID

	requestPath := strings.TrimPrefix(r.URL.Path, "/prometheus")
	if requestPath == "" {
		requestPath = "/"
	}

	backendURL := *mimirURL
	backendURL.Path = path.Join(mimirURL.Path, requestPath)
	backendURL.RawQuery = r.URL.RawQuery

	backendReq, err := http.NewRequestWithContext(r.Context(), r.Method, backendURL.String(), r.Body)
	if err != nil {
		http.Error(w, "Failed to create backend request", http.StatusInternalServerError)
		log.WithError(err).Error("creating backend request")
		return
	}

	backendReq.Header = r.Header.Clone()
	backendReq.SetBasicAuth(mimirUser, mimirPass)

	if orgID != "" {
		backendReq.Header.Set("X-Scope-OrgID", orgID)
	}

	resp, err := httpClient.Do(backendReq)
	if err != nil {
		http.Error(w, "Failed to query backend", http.StatusBadGateway)
		log.WithError(err).Error("querying Mimir")
		return
	}
	defer resp.Body.Close()

	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

func handlePush(w http.ResponseWriter, r *http.Request) {
	if !authenticate(r) {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	username, _, _ := r.BasicAuth()
	orgID := userCache[username].OrgID

	data, _ := io.ReadAll(r.Body)
	defer r.Body.Close()

	backendReq, _ := http.NewRequestWithContext(r.Context(), "POST", mimirURL.String(), strings.NewReader(string(data)))
	backendReq.Header.Set("Content-Encoding", "snappy")
	backendReq.Header.Set("Content-Type", "application/x-protobuf")
	backendReq.SetBasicAuth(mimirUser, mimirPass)

	if orgID != "" {
		backendReq.Header.Set("X-Scope-OrgID", orgID)
	}

	resp, err := httpClient.Do(backendReq)
	if err != nil {
		http.Error(w, "Failed to push to backend", http.StatusBadGateway)
		log.WithError(err).Error("pushing to Mimir")
		return
	}
	defer resp.Body.Close()

	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
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

func handleAdminUsers(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "POST":
		username := r.FormValue("username")
		password := r.FormValue("password")
		orgID := r.FormValue("org_id")

		if username == "" || password == "" {
			http.Error(w, "username & password required", http.StatusBadRequest)
			return
		}

		hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, "bcrypt error", http.StatusInternalServerError)
			return
		}

		u := User{Username: username, Password1: string(hash), OrgID: orgID}
		if err := db.WithContext(r.Context()).Save(&u).Error; err != nil {
			http.Error(w, "Failed to save user", http.StatusInternalServerError)
			return
		}

		loadUserCache()
		fmt.Fprintf(w, "Added user: %s\n", username)

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
	return validateUser(username, password)
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

