package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"database/sql"
	"encoding/base64"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/golang/protobuf/proto"
	"github.com/golang/snappy"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rqlite/gosql" // rqlite driver
	pb "github.com/prometheus/prometheus/prompb"
)

var (
	db            *sql.DB
	mimirURL      *url.URL
	mimirUsername string
	mimirPassword string
	httpClient    *http.Client
	logLevel      = INFO
)

const (
	DEBUG = iota
	INFO
	WARN
	ERROR
)

func setLogLevelFromEnv() {
	level := strings.ToUpper(os.Getenv("LOG_LEVEL"))
	switch level {
	case "DEBUG":
		logLevel = DEBUG
	case "INFO", "":
		logLevel = INFO
	case "WARN":
		logLevel = WARN
	case "ERROR":
		logLevel = ERROR
	default:
		logLevel = INFO
	}
	log.Printf("[INFO] log level set to %s", level)
}

func logDebug(format string, v ...any) {
	if logLevel <= DEBUG {
		log.Printf("[DEBUG] "+format, v...)
	}
}

func logInfo(format string, v ...any) {
	if logLevel <= INFO {
		log.Printf("[INFO] "+format, v...)
	}
}

func logWarn(format string, v ...any) {
	if logLevel <= WARN {
		log.Printf("[WARN] "+format, v...)
	}
}

func logError(format string, v ...any) {
	if logLevel <= ERROR {
		log.Printf("[ERROR] "+format, v...)
	}
}

func buildRqliteDSN(baseURL, username, password string) string {
	u, err := url.Parse(baseURL)
	if err != nil {
		log.Fatalf("[ERROR] Invalid RQLITE_URL: %v", err)
	}
	u.User = url.UserPassword(username, password)

	q := u.Query()
	q.Set("_auth", "")
	q.Set("disable_verify", "")
	u.RawQuery = q.Encode()
	return u.String()
}

func newInsecureHTTPClient() *http.Client {
	return &http.Client{
		Timeout: 10 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: true,
			},
		},
	}
}

func openRqliteDB(dsn string, client *http.Client) *sql.DB {
	connector, err := gosql.NewConnector(dsn)
	if err != nil {
		log.Fatalf("[ERROR] Failed to create rqlite connector: %v", err)
	}

	connector.Client = client
	db := sql.OpenDB(connector)
	return db
}

func getOrgID(username string) (string, error) {
	var orgID string
	err := db.QueryRow("SELECT org_id FROM users WHERE username = ?", username).Scan(&orgID)
	if err != nil {
		return "", err
	}
	return orgID, nil
}

func parseRawMetric(raw, username, orgID string) (*pb.WriteRequest, error) {
	raw = strings.TrimSpace(raw)

	idxOpen := strings.Index(raw, "{")
	if idxOpen == -1 {
		return nil, fmt.Errorf("invalid format: missing '{'")
	}
	idxClose := strings.Index(raw, "}")
	if idxClose == -1 || idxClose < idxOpen {
		return nil, fmt.Errorf("invalid format: missing '}'")
	}

	metricName := strings.TrimSpace(raw[:idxOpen])
	labelPart := raw[idxOpen+1 : idxClose]
	rest := strings.TrimSpace(raw[idxClose+1:])

	parts := strings.Fields(rest)
	if len(parts) < 2 {
		return nil, fmt.Errorf("invalid format: missing value or timestamp")
	}

	value, err := strconv.ParseFloat(parts[0], 64)
	if err != nil {
		return nil, fmt.Errorf("invalid metric value: %v", err)
	}

	tsSec, err := strconv.ParseInt(parts[1], 10, 64)
	if err != nil {
		return nil, fmt.Errorf("invalid timestamp: %v", err)
	}
	timestamp := tsSec * 1000

	labels := []pb.Label{{Name: "__name__", Value: metricName}}
	labelPart = strings.TrimSpace(labelPart)
	if labelPart != "" {
		labelPairs := strings.Split(labelPart, ",")
		for _, pair := range labelPairs {
			pair = strings.TrimSpace(pair)
			if pair == "" {
				continue
			}
			kv := strings.SplitN(pair, "=", 2)
			if len(kv) != 2 {
				return nil, fmt.Errorf("invalid label format: %s", pair)
			}
			key := strings.TrimSpace(kv[0])
			val := strings.Trim(strings.TrimSpace(kv[1]), "\"")
			labels = append(labels, pb.Label{Name: key, Value: val})
		}
	}

	labels = append(labels, pb.Label{Name: "username", Value: username})
	if orgID != "" {
		labels = append(labels, pb.Label{Name: "org_id", Value: orgID})
	}

	ts := pb.TimeSeries{
		Labels:  labels,
		Samples: []pb.Sample{{Value: value, Timestamp: timestamp}},
	}

	writeReq := &pb.WriteRequest{
		Timeseries: []pb.TimeSeries{ts},
	}
	return writeReq, nil
}

func validateEnvVars(vars ...string) {
	for _, v := range vars {
		if os.Getenv(v) == "" {
			log.Fatalf("[ERROR] Environment variable %s must be set", v)
		}
	}
}

func main() {
	log.SetFlags(log.LstdFlags | log.LUTC)
	setLogLevelFromEnv()

	validateEnvVars("RQLITE_URL", "RQLITE_USERNAME", "RQLITE_PASSWORD", "MIMIR_URL", "MIMIR_USERNAME", "MIMIR_PASSWORD")

	httpClient = newInsecureHTTPClient()

	rqliteURL := os.Getenv("RQLITE_URL")
	rqliteUser := os.Getenv("RQLITE_USERNAME")
	rqlitePass := os.Getenv("RQLITE_PASSWORD")
	mimirURLStr := os.Getenv("MIMIR_URL")
	mimirUsername = os.Getenv("MIMIR_USERNAME")
	mimirPassword = os.Getenv("MIMIR_PASSWORD")

	dsn := buildRqliteDSN(rqliteURL, rqliteUser, rqlitePass)
	db = openRqliteDB(dsn, httpClient)
	defer db.Close()

	var err error
	mimirURL, err = url.Parse(mimirURLStr)
	if err != nil {
		log.Fatalf("[ERROR] Invalid MIMIR_URL: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/api/v1/push", handlePush)
	mux.Handle("/metrics", promhttp.Handler())
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	srv := &http.Server{
		Addr:    ":8080",
		Handler: mux,
	}

	// graceful shutdown
	go func() {
		logInfo("HTTP server running on :8080")
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[ERROR] HTTP server error: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop
	logInfo("Shutting down gracefully...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("[ERROR] Server forced to shutdown: %v", err)
	}
	logInfo("Server stopped.")
}

func handlePush(w http.ResponseWriter, r *http.Request) {
	if !authenticate(r) {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	username, _, ok := r.BasicAuth()
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	orgID, err := getOrgID(username)
	if err != nil {
		http.Error(w, "Failed to retrieve org_id", http.StatusInternalServerError)
		return
	}

	data, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Failed to read request body", http.StatusInternalServerError)
		return
	}
	defer r.Body.Close()

	writeReq, err := parseRawMetric(string(data), username, orgID)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to parse metric: %v", err), http.StatusBadRequest)
		logWarn("Error parsing metric: %v, Raw data: %s", err, string(data))
		return
	}

	serialized, err := proto.Marshal(writeReq)
	if err != nil {
		http.Error(w, "Failed to marshal protobuf message", http.StatusInternalServerError)
		logError("Error marshaling protobuf: %v, WriteRequest: %+v", err, writeReq)
		return
	}

	compressedData := snappy.Encode(nil, serialized)

	backendReq, err := http.NewRequestWithContext(r.Context(), "POST", mimirURL.String(), bytes.NewReader(compressedData))
	if err != nil {
		http.Error(w, "Failed to create backend request", http.StatusInternalServerError)
		logError("Error creating backend request: %v", err)
		return
	}
	backendReq.Header.Set("Content-Type", "application/x-protobuf")
	backendReq.Header.Set("Content-Encoding", "snappy")
	backendReq.SetBasicAuth(mimirUsername, mimirPassword)

	if orgID != "" {
		backendReq.Header.Set("X-Scope-OrgID", orgID)
	}

	resp, err := httpClient.Do(backendReq)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to push to Mimir backend: %v", err), http.StatusBadGateway)
		logError("Error pushing to Mimir: %v, Mimir URL: %s", err, mimirURL.String())
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		http.Error(w, fmt.Sprintf("Mimir returned error: %s (Status Code: %d)", string(body), resp.StatusCode), http.StatusBadGateway)
		logError("Mimir returned error: %s (Status Code: %d), Mimir URL: %s", string(body), resp.StatusCode, mimirURL.String())
		return
	}

	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

func authenticate(r *http.Request) bool {
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
	return validateUser(username, password)
}

func validateUser(username, password string) bool {
	var storedPassword string
	err := db.QueryRow("SELECT password FROM users WHERE username = ?", username).Scan(&storedPassword)
	if err != nil {
		return false
	}
	return password == storedPassword
}
