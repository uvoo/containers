package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"database/sql"
	"encoding/base64"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"path"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/golang/protobuf/proto"
	"github.com/golang/snappy"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/sirupsen/logrus"
	"golang.org/x/crypto/bcrypt"

	_ "github.com/lib/pq"
	pb "github.com/prometheus/prometheus/prompb"
)

var (
	store      UserStore
	mimirURL   *url.URL
	mimirUser  string
	mimirPass  string
	httpClient *http.Client
	log        = logrus.New()

	adminUser = os.Getenv("ADMIN_USERNAME")
	adminPass = os.Getenv("ADMIN_PASSWORD")

	userCache = make(map[string]User)
	cacheMux  = &sync.RWMutex{}
	cacheTTL  = 30 * time.Second
)

type User struct {
	Username         string
	Password1        string
	Password2        string
	OrgID            string
	LastFailedIP     string
	LastFailedReason string
}

type UserStore interface {
	LoadAll() (map[string]User, error)
}

type PostgresStore struct {
	db *sql.DB
}

func main() {
	initLogger()
	validateEnvVars("MIMIR_URL", "MIMIR_USERNAME", "MIMIR_PASSWORD")
	store = openStore()

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

	go cacheRefresher()

	mux := http.NewServeMux()
	mux.HandleFunc("/prometheus/", handlePrometheusQuery)
	mux.HandleFunc("/api/v1/push", handlePush)
	mux.Handle("/metrics", promhttp.Handler())
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	if adminUser != "" && adminPass != "" {
    	mux.HandleFunc("/admin/refresh", handleAdminRefresh)
		mux.HandleFunc("/admin/users", handleAdminUsers)
		log.Info("Admin API enabled at /admin/users")
	}

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

// -------------------------- User Store --------------------------

func (p *PostgresStore) LoadAll() (map[string]User, error) {
	tmp := make(map[string]User)
	rows, err := p.db.Query(`SELECT username, password1, password2, org_id, last_failed_ip, last_failed_reason FROM users`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var u User
		if err := rows.Scan(&u.Username, &u.Password1, &u.Password2, &u.OrgID, &u.LastFailedIP, &u.LastFailedReason); err != nil {
			continue
		}
		tmp[u.Username] = u
	}
	return tmp, nil
}

// -------------------------- Admin --------------------------

func authenticateAdmin(r *http.Request) bool {
	if adminUser == "" || adminPass == "" {
		return false
	}
	decoded, err := base64.StdEncoding.DecodeString(strings.TrimPrefix(r.Header.Get("Authorization"), "Basic "))
	if err != nil {
		return false
	}
	parts := strings.SplitN(string(decoded), ":", 2)
	return len(parts) == 2 && parts[0] == adminUser && parts[1] == adminPass
}

func handleAdminUsers(w http.ResponseWriter, r *http.Request) {
	if !authenticateAdmin(r) {
		w.Header().Set("WWW-Authenticate", `Basic realm="Restricted"`)
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	switch r.Method {
	case http.MethodGet:
		handleListUsers(w)
	case http.MethodPost:
		handleAddUser(w, r)
	case http.MethodDelete:
		handleDeleteUser(w, r)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func handleListUsers(w http.ResponseWriter) {
	rows, err := store.(*PostgresStore).db.Query(
		`SELECT username, org_id, last_failed_ip, last_failed_reason FROM users`)
	if err != nil {
		http.Error(w, "Failed to fetch users", 500)
		return
	}
	defer rows.Close()
	for rows.Next() {
		var u, org, ip, reason string
		rows.Scan(&u, &org, &ip, &reason)
		fmt.Fprintf(w, "user: %s, org: %s, last_failed_ip: %s, last_failed_reason: %s\n", u, org, ip, reason)
	}
}

func handleAddUser(w http.ResponseWriter, r *http.Request) {
	r.ParseForm()
	username := r.Form.Get("username")
	password := r.Form.Get("password")
	org := r.Form.Get("org_id")

	if username == "" || password == "" || org == "" {
		http.Error(w, "username, password, org_id required", 400)
		return
	}

	hash, _ := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)

	_, err := store.(*PostgresStore).db.Exec(
		`INSERT INTO users (username, password1, org_id) VALUES ($1, $2, $3) 
		 ON CONFLICT(username) DO UPDATE SET password1=$2, org_id=$3`,
		username, string(hash), org)
	if err != nil {
		http.Error(w, "Failed to insert user", 500)
		return
	}
	w.Write([]byte("User added/updated\n"))
}

func handleDeleteUser(w http.ResponseWriter, r *http.Request) {
	r.ParseForm()
	username := r.Form.Get("username")
	if username == "" {
		http.Error(w, "username required", 400)
		return
	}

	_, err := store.(*PostgresStore).db.Exec(`DELETE FROM users WHERE username=$1`, username)
	if err != nil {
		http.Error(w, "Failed to delete user", 500)
		return
	}
	w.Write([]byte("User deleted\n"))
}

// -------------------------- Auth & Helpers --------------------------

func authenticate(r *http.Request) bool {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" || !strings.HasPrefix(authHeader, "Basic ") {
		return false
	}
	decoded, _ := base64.StdEncoding.DecodeString(strings.TrimPrefix(authHeader, "Basic "))
	parts := strings.SplitN(string(decoded), ":", 2)
	if len(parts) != 2 {
		return false
	}
	return validateUser(parts[0], parts[1], r)
}

func validateUser(username, password string, r *http.Request) bool {
	cacheMux.RLock()
	u, ok := userCache[username]
	cacheMux.RUnlock()
	if !ok {
		logAuthFailure(username, r, "not found")
		return false
	}

	if bcrypt.CompareHashAndPassword([]byte(u.Password1), []byte(password)) == nil {
		return true
	}
	if u.Password2 != "" && bcrypt.CompareHashAndPassword([]byte(u.Password2), []byte(password)) == nil {
		return true
	}

	logAuthFailure(username, r, "invalid password")
	return false
}

func logAuthFailure(username string, r *http.Request, reason string) {
	ip := r.RemoteAddr
	if xfwd := r.Header.Get("X-Forwarded-For"); xfwd != "" {
		ip = strings.Split(xfwd, ",")[0]
	}
	_, _ = store.(*PostgresStore).db.Exec(
		`UPDATE users SET last_failed_ip=$1, last_failed_reason=$2 WHERE username=$3`,
		ip, reason, username,
	)
	log.WithFields(logrus.Fields{"user": username, "ip": ip, "reason": reason}).Warn("Auth failure")
}

// -------------------------- Prom & Push --------------------------

func handlePrometheusQuery(w http.ResponseWriter, r *http.Request) {
	if !authenticate(r) {
		http.Error(w, "Unauthorized", 401)
		return
	}
	username, _, _ := r.BasicAuth()
	orgID, _ := getOrgID(username)

	requestPath := strings.TrimPrefix(r.URL.Path, "/prometheus")
	backendURL := *mimirURL
	backendURL.Path = path.Join(mimirURL.Path, requestPath)
	backendURL.RawQuery = r.URL.RawQuery

	backendReq, _ := http.NewRequestWithContext(r.Context(), r.Method, backendURL.String(), r.Body)
	backendReq.Header = r.Header.Clone()
	backendReq.SetBasicAuth(mimirUser, mimirPass)
	if orgID != "" {
		backendReq.Header.Set("X-Scope-OrgID", orgID)
	}

	resp, err := httpClient.Do(backendReq)
	if err != nil {
		http.Error(w, "Failed to query Mimir", 502)
		return
	}
	defer resp.Body.Close()
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

func handlePush(w http.ResponseWriter, r *http.Request) {
	if !authenticate(r) {
		http.Error(w, "Unauthorized", 401)
		return
	}
	username, _, _ := r.BasicAuth()
	orgID, _ := getOrgID(username)

	data, _ := io.ReadAll(r.Body)
	defer r.Body.Close()

	var compressed []byte
	if isLikelyText(data) {
		wr, _ := parseRawMetric(string(data), username, orgID)
		bin, _ := proto.Marshal(wr)
		compressed = snappy.Encode(nil, bin)
	} else {
		compressed = data
	}

	backendReq, _ := http.NewRequestWithContext(r.Context(), "POST", mimirURL.String(), bytes.NewReader(compressed))
	backendReq.Header.Set("Content-Encoding", "snappy")
	backendReq.SetBasicAuth(mimirUser, mimirPass)
	if orgID != "" {
		backendReq.Header.Set("X-Scope-OrgID", orgID)
	}

	resp, _ := httpClient.Do(backendReq)
	defer resp.Body.Close()
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

// -------------------------- Misc --------------------------

func getOrgID(username string) (string, error) {
	cacheMux.RLock()
	defer cacheMux.RUnlock()
	u, ok := userCache[username]
	if !ok {
		return "", fmt.Errorf("user not found")
	}
	return u.OrgID, nil
}

func parseRawMetric(raw, username, orgID string) (*pb.WriteRequest, error) {
	raw = strings.TrimSpace(raw)
	idxOpen := strings.Index(raw, "{")
	idxClose := strings.Index(raw, "}")
	metricName := strings.TrimSpace(raw[:idxOpen])
	labelPart := raw[idxOpen+1 : idxClose]
	rest := strings.TrimSpace(raw[idxClose+1:])

	parts := strings.Fields(rest)
	value, _ := strconv.ParseFloat(parts[0], 64)
	timestamp, _ := strconv.ParseInt(parts[1], 10, 64)

	labels := []pb.Label{{Name: "__name__", Value: metricName}}
	for _, pair := range strings.Split(labelPart, ",") {
		kv := strings.SplitN(pair, "=", 2)
		labels = append(labels, pb.Label{Name: strings.TrimSpace(kv[0]), Value: strings.Trim(kv[1], `"`)})

	}
	labels = append(labels, pb.Label{Name: "username", Value: username})
	if orgID != "" {
		labels = append(labels, pb.Label{Name: "org_id", Value: orgID})
	}

	return &pb.WriteRequest{
		Timeseries: []pb.TimeSeries{{Labels: labels, Samples: []pb.Sample{{Value: value, Timestamp: timestamp}}}},
	}, nil
}

func isLikelyText(data []byte) bool {
	for _, c := range data {
		if (c < 32 && c != 9 && c != 10 && c != 13) || c > 126 {
			return false
		}
	}
	return true
}

func initLogger() {
	level, _ := logrus.ParseLevel(os.Getenv("LOG_LEVEL"))
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

func openStore() UserStore {
	dsn := fmt.Sprintf(
		"host=%s port=%s dbname=%s user=%s password=%s sslmode=disable",
		os.Getenv("POSTGRES_HOST"), os.Getenv("POSTGRES_PORT"),
		os.Getenv("POSTGRES_DB"), os.Getenv("POSTGRES_USER"), os.Getenv("POSTGRES_PASSWORD"),
	)
	db, _ := sql.Open("postgres", dsn)
	db.Exec(`CREATE TABLE IF NOT EXISTS users (
		username TEXT PRIMARY KEY,
		password1 TEXT NOT NULL,
		password2 TEXT,
		org_id TEXT,
		last_failed_ip TEXT,
		last_failed_reason TEXT
	)`)
	return &PostgresStore{db: db}
}

func cacheRefresher() {
	for {
		loadUserCache()
		time.Sleep(cacheTTL)
	}
}

func loadUserCache() {
	tmp, err := store.LoadAll()
	if err != nil {
		log.WithError(err).Error("Failed to load user cache")
		return
	}
	cacheMux.Lock()
	userCache = tmp
	cacheMux.Unlock()
}

func handleAdminRefresh(w http.ResponseWriter, r *http.Request) {
    if !checkAdminAuth(r) {
        http.Error(w, "Unauthorized", http.StatusUnauthorized)
        return
    }

    log.Info("Forcing user cache refresh via admin/refresh")
    loadUserCache() // force reload

    // capture current cache
    cacheMux.RLock()
    defer cacheMux.RUnlock()

    var sb strings.Builder
    sb.WriteString("Current users in cache:\n")
    for k, v := range userCache {
        sb.WriteString(fmt.Sprintf(" - %s (orgID: %s)\n", k, v.OrgID))
    }

    log.Info("User cache refreshed via admin/refresh")
    log.Info(sb.String())

    w.Header().Set("Content-Type", "text/plain")
    w.Write([]byte(sb.String()))
}

func checkAdminAuth(r *http.Request) bool {
    authHeader := r.Header.Get("Authorization")
    if authHeader == "" || !strings.HasPrefix(authHeader, "Basic ") {
        return false
    }
    decoded, err := base64.StdEncoding.DecodeString(strings.TrimPrefix(authHeader, "Basic "))
    if err != nil {
        return false
    }
    parts := strings.SplitN(string(decoded), ":", 2)
    if len(parts) != 2 {
        return false
    }
    username, password := parts[0], parts[1]
    return username == adminUser && password == adminPass
}
