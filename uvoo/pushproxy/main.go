package main

import (
	"bytes"
	// "encoding/base64"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	// "strings"
	"time"

	"gopkg.in/yaml.v2"

	"github.com/golang/protobuf/proto"
	"github.com/golang/snappy"
	pb "github.com/prometheus/prometheus/prompb"
)

// User represents a user entry from the YAML secret.
type User struct {
	Username string `yaml:"username"`
	Password string `yaml:"password"`
	OrgID    string `yaml:"org_id"`
}

// Users is the top-level structure for the YAML file.
type Users struct {
	Users []User `yaml:"users"`
}

// usersMap holds users keyed by username for quick lookup.
var usersMap map[string]User

var pushURL *url.URL
var pushUsername, pushPassword string
var httpClient *http.Client

func getOrgID(username string) (string, error) {
	u, exists := usersMap[username]
	if !exists {
		return "", fmt.Errorf("user %s not found", username)
	}
	return u.OrgID, nil
}

func main() {
	// Load user authentication details from YAML file.
	usersFile := os.Getenv("USER_SECRET_FILE")
	if usersFile == "" {
		usersFile = "/etc/secrets/users.yaml"
	}
	data, err := os.ReadFile(usersFile)
	if err != nil {
		log.Fatalf("Failed to read users secret file: %v", err)
	}
	var users Users
	if err := yaml.Unmarshal(data, &users); err != nil {
		log.Fatalf("Failed to parse users YAML: %v", err)
	}
	usersMap = make(map[string]User)
	for _, u := range users.Users {
		usersMap[u.Username] = u
	}

	// Set up the push backend.
	pushURLStr := os.Getenv("PUSH_URL")
	if pushURLStr == "" {
		pushURLStr = "https://examplepush.example.com/api/v1/push"
	}
	pushURL, err = url.Parse(pushURLStr)
	if err != nil {
		log.Fatalf("Invalid PUSH_URL: %v", err)
	}

	pushUsername = os.Getenv("PUSH_USERNAME")
	pushPassword = os.Getenv("PUSH_PASSWORD")

	httpClient = &http.Client{
		Timeout: 10 * time.Second,
	}

	http.HandleFunc("/api/v1/push", func(w http.ResponseWriter, r *http.Request) {
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

		contentType := r.Header.Get("Content-Type")
		var writeReq *pb.WriteRequest

		if contentType == "application/x-protobuf" {
			// Handle Protobuf-encoded data
			compressedData, err := io.ReadAll(r.Body)
			if err != nil {
				http.Error(w, "Failed to read request body", http.StatusInternalServerError)
				return
			}
			r.Body.Close()

			uncompressed, err := snappy.Decode(nil, compressedData)
			if err != nil {
				http.Error(w, "Failed to uncompress protobuf data", http.StatusBadRequest)
				return
			}

			writeReq = &pb.WriteRequest{}
			if err := proto.Unmarshal(uncompressed, writeReq); err != nil {
				http.Error(w, "Failed to unmarshal protobuf message", http.StatusBadRequest)
				return
			}

			// Add username and org_id labels to each time series.
			for i := range writeReq.Timeseries {
				writeReq.Timeseries[i].Labels = append(writeReq.Timeseries[i].Labels, pb.Label{Name: "username", Value: username})
				if orgID != "" {
					writeReq.Timeseries[i].Labels = append(writeReq.Timeseries[i].Labels, pb.Label{Name: "org_id", Value: orgID})
				}
			}

			// Marshal the updated request back to protobuf
			updatedData, err := proto.Marshal(writeReq)
			if err != nil {
				http.Error(w, "Failed to marshal updated protobuf data", http.StatusInternalServerError)
				return
			}

			// Compress it again with Snappy
			compressedData = snappy.Encode(nil, updatedData)

			// Forward the request to the push backend
			forwardRequest(w, compressedData, "application/x-protobuf")

		} else {
			http.Error(w, "Unsupported content type", http.StatusUnsupportedMediaType)
			return
		}
	})

	log.Println("Listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

// forwardRequest forwards the processed request to the push backend.
func forwardRequest(w http.ResponseWriter, data []byte, contentType string) {
	req, err := http.NewRequest("POST", pushURL.String(), bytes.NewBuffer(data))
	if err != nil {
		http.Error(w, "Failed to create forward request", http.StatusInternalServerError)
		return
	}
	req.SetBasicAuth(pushUsername, pushPassword)
	req.Header.Set("Content-Type", contentType)

	resp, err := httpClient.Do(req)
	if err != nil {
		http.Error(w, "Failed to forward request to backend", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	w.WriteHeader(resp.StatusCode)
	w.Write(body)
}

// authenticate checks if the request has valid credentials.
func authenticate(r *http.Request) bool {
	username, password, ok := r.BasicAuth()
	if !ok {
		return false
	}

	user, exists := usersMap[username]
	if !exists || user.Password != password {
		return false
	}

	return true
}

