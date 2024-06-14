package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os/exec"

	"github.com/gorilla/mux"
)

type MTRResult struct {
	// Define the structure to match MTR JSON output
}

type Hub struct {
	Count int     `json:"count"`
	Host  string  `json:"host"`
	Loss  float64 `json:"Loss%"`
	Snt   int     `json:"Snt"`
	Last  float64 `json:"Last"`
	Avg   float64 `json:"Avg"`
	Best  float64 `json:"Best"`
	Wrst  float64 `json:"Wrst"`
	StDev float64 `json:"StDev"`
}

type Report struct {
	Mtr struct {
		Src        string `json:"src"`
		Dst        string `json:"dst"`
		Tos        int    `json:"tos"`
		Tests      int    `json:"tests"`
		Psize      string `json:"psize"`
		Bitpattern string `json:"bitpattern"`
	} `json:"mtr"`
	Hubs []Hub `json:"hubs"`
}

func runMTR(target string) (string, error) {
	// cmd := exec.Command("mtr", "-n", "-c", "9", "--report", "--json", target)
	cmd := exec.Command("mtr", "-n", "-c", "9", "--report", "--json", target)
	// cmd := exec.Command("mtr", "-n", "-c", "9", "--report", "--json", "jq" "'.report.hubs |= map(select(.host != \"???\"))'", target)
	// cmd := exec.Command("mtr", "-n", "-c", "9", "--report", "--json", "jq", "'.report.hubs |= map(select(.host != \"???\"))'", target)
	// cmd := exec.Command("mtr", "-n", "-c", "9", "--report", "--json", "|", "jq", "'.report.hubs |= map(select(.host != \"???\"))'", target)
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return string(out), nil
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

	//-----------------------------------------------
	var report struct {
		Report Report `json:"report"`
	}
	err = json.Unmarshal([]byte(result), &report)
	if err != nil {
		fmt.Println(err)
		return
	}

	var filteredHubs []Hub
	for _, hub := range report.Report.Hubs {
		if hub.Host != "???" {
			filteredHubs = append(filteredHubs, hub)
		}
	}

	report.Report.Hubs = filteredHubs

	// filteredData, err := json.Marshal(report)
	filteredData, err := json.MarshalIndent(report, "", "    ")
	if err != nil {
		fmt.Println(err)
		return
	}

	// fmt.Println(string(filteredData))

	// w.Write([]byte(result))

	/* jsonData, err := json.MarshalIndent(filteredData, "", "    ")
	   if err != nil {
	       fmt.Println(err)
	       return
	   }
	*/

	// fmt.Println(string(jsonData))

	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(filteredData))
	// w.Write([]byte(jsonData))
}

func main() {
	r := mux.NewRouter()
	r.HandleFunc("/probe", probeHandler).Methods("GET")
	http.Handle("/", r)
	log.Println("Starting server on :9116")
	log.Fatal(http.ListenAndServe(":9116", nil))
}
