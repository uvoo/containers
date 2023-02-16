package main

import (
        "crypto/tls"
        "fmt"
        "log"
        "net/http"
        "os"
        "os/exec"
        "strconv"
        // "bytes"
)

var httpPort = 8080
var httpsPort = 8443
var tlsFqdn = "foo"

func logRequest(handler http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
                log.Printf("%s %s %s\n", r.RemoteAddr, r.Method, r.URL)
                handler.ServeHTTP(w, r)
        })
}

func genTls() {

        if _, err := os.Stat("tls.key"); err != nil {
                err = nil
                var cmd_txt = fmt.Sprintf("fqdn=%s; openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout tls.key -out tls.crt -subj \"/CN=$fqdn\" -addext \"subjectAltName = DNS:$fqdn\"", tlsFqdn)
                fmt.Printf("Create fqdn %s tls.crt tls.key files.\n\n", tlsFqdn)
                cmd := exec.Command("bash", "-c", cmd_txt)
                out, _ := cmd.CombinedOutput()

                if err != nil {
                        fmt.Println(err.Error())
                        return
                }
                fmt.Printf("%s\n", out)
        }
}

func EchoHandler(writer http.ResponseWriter, request *http.Request) {
        log.Println("Echoing back request made to " + request.URL.Path + " to client (" + request.RemoteAddr + ")")
        writer.Header().Set("Access-Control-Allow-Origin", "*")
        writer.Header().Set("Access-Control-Allow-Headers", "Content-Range, Content-Disposition, Content-Type, ETag")
        request.Write(writer)
}

func serveHTTP(mux *http.ServeMux, errs chan<- error) {
        log.Printf("starting http server on port %v.", httpPort)
        errs <- http.ListenAndServe(":"+strconv.Itoa(httpPort), mux)
}

func serveHTTPS(mux *http.ServeMux, errs chan<- error) {
        cfg := &tls.Config{
                MinVersion:               tls.VersionTLS12,
                CurvePreferences:         []tls.CurveID{tls.CurveP521, tls.CurveP384, tls.CurveP256},
                PreferServerCipherSuites: true,
                CipherSuites: []uint16{
                        tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
                        tls.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,
                        tls.TLS_RSA_WITH_AES_256_GCM_SHA384,
                        tls.TLS_RSA_WITH_AES_256_CBC_SHA,
                },
        }
        https := &http.Server{
                Addr:         fmt.Sprintf(":%d", httpsPort),
                TLSConfig:    cfg,
                Handler:      mux,
                TLSNextProto: make(map[string]func(*http.Server, *tls.Conn, http.Handler), 0),
        }
        log.Printf("starting https server on port %v.", httpsPort)
        errs <- https.ListenAndServeTLS("tls.crt", "tls.key")
}

func main() {
        genTls()
        mux := http.NewServeMux()
        mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
                w.Header().Set("Access-Control-Allow-Origin", "*")
                w.Header().Set("Access-Control-Allow-Headers",
                        "Content-Range,Content-Disposition, Content-Type, ETag")
                r.Write(w)
                // r.URL.Path
                log.Printf("%s %s %s %s %s %s\n",
                        r.RemoteAddr,
                        r.Host,
                        r.Proto,
                        r.Method,
                        r.URL,
                        r.Header.Get("X-FORWARDED-FOR"))
        })
        errs := make(chan error, 1)
        go serveHTTP(mux, errs)
        go serveHTTPS(mux, errs)
        log.Fatal(<-errs) // block until an error
}
