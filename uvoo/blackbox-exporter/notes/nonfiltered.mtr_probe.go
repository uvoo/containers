package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os/exec"
	// "strconv"
	"strings"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Define the MTRResult struct to match MTR JSON output
type MTRResult struct {
	Report struct {
		Hubs []struct {
			Count int     `json:"count"`
			Loss  float64 `json:"Loss%"`
			Snt   int     `json:"Snt"`
			Last  float64 `json:"Last"`
			Avg   float64 `json:"Avg"`
			Best  float64 `json:"Best"`
			Wrst  float64 `json:"Wrst"`
			StDev float64 `json:"StDev"`
			Host  string  `json:"Host"`
		} `json:"hubs"`
	} `json:"report"`
}

var (
	// Define Prometheus metrics
	mtrLoss = prometheus.NewGaugeVec(prometheus.GaugeOpts{
		Name: "mtr_loss_percentage",
		Help: "Packet loss percentage reported by MTR",
	}, []string{"host", "target"})

	mtrAvg = prometheus.NewGaugeVec(prometheus.GaugeOpts{
		Name: "mtr_avg_latency",
		Help: "Average latency reported by MTR",
	}, []string{"host", "target"})

	mtrBest = prometheus.NewGaugeVec(prometheus.GaugeOpts{
		Name: "mtr_best_latency",
		Help: "Best latency reported by MTR",
	}, []string{"host", "target"})

	mtrWrst = prometheus.NewGaugeVec(prometheus.GaugeOpts{
		Name: "mtr_wrst_latency",
		Help: "Worst latency reported by MTR",
	}, []string{"host", "target"})
)

func init() {
	// Register Prometheus metrics
	prometheus.MustRegister(mtrLoss)
	prometheus.MustRegister(mtrAvg)
	prometheus.MustRegister(mtrBest)
	prometheus.MustRegister(mtrWrst)
}

func runMTR(target string) (MTRResult, error) {
	cmd := exec.Command("mtr", "-n", "-c", "5", "--report", "--json", target)
	out, err := cmd.Output()
	if err != nil {
		return MTRResult{}, err
	}

	var result MTRResult
	err = json.Unmarshal(out, &result)
	if err != nil {
		return MTRResult{}, err
	}
	return result, nil
}

func probeHandler(w http.ResponseWriter, r *http.Request) {
	target := r.URL.Query().Get("target")
	if target == "" {
		target = "8.8.8.8"
	}

	result, err := runMTR(target)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	for _, hub := range result.Report.Hubs {
		host := strings.TrimSpace(hub.Host)
		mtrLoss.WithLabelValues(host, target).Set(hub.Loss)
		mtrAvg.WithLabelValues(host, target).Set(hub.Avg)
		mtrBest.WithLabelValues(host, target).Set(hub.Best)
		mtrWrst.WithLabelValues(host, target).Set(hub.Wrst)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func main() {
	r := mux.NewRouter()
	r.HandleFunc("/probe", probeHandler).Methods("GET")
	r.Handle("/metrics", promhttp.Handler())

	log.Println("Starting server on :9116")
	log.Fatal(http.ListenAndServe(":9116", r))
}
