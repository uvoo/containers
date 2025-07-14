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
        "strconv"
        "strings"
        "sync"
        "syscall"
        "time"

        "github.com/golang/protobuf/proto"
        "github.com/golang/snappy"
        "github.com/prometheus/client_golang/prometheus/promhttp"
        "github.com/rqlite/gorqlite"
        "github.com/sirupsen/logrus"

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

        userCache = make(map[string]User)
        cacheMux  = &sync.RWMutex{}
        cacheTTL  = 30 * time.Second
)

type User struct {
        Username string
        Password string
        OrgID    string
}

type UserStore interface {
        LoadAll() (map[string]User, error)
}

type PostgresStore struct {
        db *sql.DB
}

type RqliteStore struct {
        conn *gorqlite.Connection
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

        // setup HTTP client
        if os.Getenv("BACKEND_SKIP_TLS_VERIFY") == "true" {
                log.Warn("BACKEND_SKIP_TLS_VERIFY is true — skipping TLS verification for backend requests!")
                httpClient = &http.Client{
                        Timeout: 30 * time.Second,
                        Transport: &http.Transport{
                                TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
                        },
                }
        } else {
                httpClient = &http.Client{
                        Timeout: 30 * time.Second,
                }
        }

        if ttlStr := os.Getenv("USER_CACHE_TTL"); ttlStr != "" {
                if d, err := time.ParseDuration(ttlStr); err == nil {
                        cacheTTL = d
                }
        }

        go cacheRefresher()

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
                loadUserCache()
                time.Sleep(cacheTTL)
        }
}

func loadUserCache() {
        log.Info("Loading user cache...")
        tmp, err := store.LoadAll()
        if err != nil {
                log.WithError(err).Error("Failed to load user cache")
                return
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
        return ok && u.Password == password
}

func getOrgID(username string) (string, error) {
        cacheMux.RLock()
        defer cacheMux.RUnlock()
        u, ok := userCache[username]
        if !ok {
                return "", fmt.Errorf("user not found")
        }
        return u.OrgID, nil
}

func (p *PostgresStore) LoadAll() (map[string]User, error) {
        tmp := make(map[string]User)
        rows, err := p.db.Query("SELECT username, password, org_id FROM users")
        if err != nil {
                return nil, err
        }
        defer rows.Close()
        for rows.Next() {
                var u User
                if err := rows.Scan(&u.Username, &u.Password, &u.OrgID); err != nil {
                        continue
                }
                tmp[u.Username] = u
        }
        return tmp, nil
}

func (r *RqliteStore) LoadAll() (map[string]User, error) {
        tmp := make(map[string]User)

        rs, err := r.conn.QueryOne("SELECT username, password, org_id FROM users")
        if err != nil {
                return nil, err
        }

        for rs.Next() {
                var u User
                if err := rs.Scan(&u.Username, &u.Password, &u.OrgID); err != nil {
                        log.WithError(err).Warn("failed to scan row")
                        continue
                }
                tmp[u.Username] = u
        }

        return tmp, nil
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

        var (
                compressedData []byte
                contentType    string
        )

        if isLikelyText(data) {
                log.Info("Received text/plain metric, parsing…")
                writeReq, err := parseRawMetric(string(data), username, orgID)
                if err != nil {
                        http.Error(w, fmt.Sprintf("Failed to parse metric: %v", err), http.StatusBadRequest)
                        log.WithFields(logrus.Fields{
                                "err":      err,
                                "raw_data": string(data),
                        }).Warn("failed to parse metric")
                        return
                }

                serialized, err := proto.Marshal(writeReq)
                if err != nil {
                        http.Error(w, "Failed to marshal protobuf message", http.StatusInternalServerError)
                        log.WithError(err).Error("error marshaling protobuf")
                        return
                }

                compressedData = snappy.Encode(nil, serialized)
                contentType = "text/plain"
        } else {
                log.Info("Received snappy/protobuf metric, forwarding as-is…")
                compressedData = data
                contentType = "application/x-protobuf"
        }

        backendReq, err := http.NewRequestWithContext(r.Context(), "POST", mimirURL.String(), bytes.NewReader(compressedData))
        if err != nil {
                http.Error(w, "Failed to create backend request", http.StatusInternalServerError)
                log.WithError(err).Error("error creating backend request")
                return
        }
        backendReq.Header.Set("Content-Encoding", "snappy")
        backendReq.Header.Set("Content-Type", contentType)
        backendReq.SetBasicAuth(mimirUser, mimirPass)

        if orgID != "" {
                backendReq.Header.Set("X-Scope-OrgID", orgID)
        }

        resp, err := httpClient.Do(backendReq)
        if err != nil {
                http.Error(w, fmt.Sprintf("Failed to push to Mimir backend: %v", err), http.StatusBadGateway)
                log.WithError(err).Error("error pushing to Mimir")
                return
        }
        defer resp.Body.Close()

        if resp.StatusCode >= 400 {
                body, _ := io.ReadAll(resp.Body)
                http.Error(w, fmt.Sprintf("Mimir returned error: %s (Status Code: %d)", string(body), resp.StatusCode), http.StatusBadGateway)
                log.WithFields(logrus.Fields{
                        "status":   resp.StatusCode,
                        "body":     string(body),
                        "username": username,
                        "org_id":   orgID,
                }).Error("Mimir returned error")
                return
        }

        w.WriteHeader(resp.StatusCode)
        io.Copy(w, resp.Body)
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

        timestamp, err := strconv.ParseInt(parts[1], 10, 64)
        if err != nil {
                return nil, fmt.Errorf("invalid timestamp: %v", err)
        }

        labels := []pb.Label{{Name: "__name__", Value: metricName}}
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

        return &pb.WriteRequest{
                Timeseries: []pb.TimeSeries{ts},
        }, nil
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

func isLikelyText(data []byte) bool {
        max := len(data)
        if max > 512 {
                max = 512
        }
        for i := 0; i < max; i++ {
                c := data[i]
                if (c < 32 && c != 9 && c != 10 && c != 13) || c > 126 {
                        return false
                }
        }
        return true
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
        log.SetFormatter(&logrus.JSONFormatter{
                TimestampFormat: time.RFC3339,
        })
        log.SetOutput(os.Stdout)
        log.WithField("level", level).Info("log level set")
}

func validateEnvVars(vars ...string) {
        for _, v := range vars {
                if os.Getenv(v) == "" {
                        log.WithField("var", v).Fatal("Environment variable must be set")
                }
        }
}

func openStore() UserStore {
        dbDriver := strings.ToLower(os.Getenv("DB_DRIVER"))
        if dbDriver == "" {
                dbDriver = "postgres"
        }
        if dbDriver == "postgres" {
                validateEnvVars("POSTGRES_HOST", "POSTGRES_PORT", "POSTGRES_DB", "POSTGRES_USER", "POSTGRES_PASSWORD")
                dsn := fmt.Sprintf(
                        "host=%s port=%s dbname=%s user=%s password=%s sslmode=disable",
                        os.Getenv("POSTGRES_HOST"),
                        os.Getenv("POSTGRES_PORT"),
                        os.Getenv("POSTGRES_DB"),
                        os.Getenv("POSTGRES_USER"),
                        os.Getenv("POSTGRES_PASSWORD"),
                )
                db, err := sql.Open("postgres", dsn)
                if err != nil {
                        log.WithError(err).Fatal("failed to connect to Postgres")
                }
                log.Info("Connected to Postgres")
                return &PostgresStore{db: db}
        } else if dbDriver == "rqlite" {
                validateEnvVars("RQLITE_URL")
                conn, err := gorqlite.Open(os.Getenv("RQLITE_URL"))
                if err != nil {
                        log.WithError(err).Fatal("failed to connect to rqlite")
                }
                log.Info("Connected to rqlite")
                return &RqliteStore{conn: conn}
        } else {
                log.Fatalf("Unsupported DB_DRIVER: %s", dbDriver)
        }
        return nil
}
