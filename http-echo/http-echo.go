package main

import (
        "log"
        "net/http"
        "os"
)

const DefaultHttpPort = "8080"
const DefaultHttpsPort = "8443"

func getHttpPort() string {
        httpPort := os.Getenv("HTTP_PORT")
        if httpPort != "" {
                return httpPort
        }
        return DefaultHttpPort
}

func getHttpsPort() string {
        httpsPort := os.Getenv("HTTPS_PORT")
        if httpsPort != "" {
                return httpsPort
        }
        return DefaultHttpsPort
}

func EchoHandler(writer http.ResponseWriter, request *http.Request) {
        log.Println("Echoing back request made to " + request.URL.Path + " to client (" + request.RemoteAddr + ")")
        writer.Header().Set("Access-Control-Allow-Origin", "*")
        writer.Header().Set("Access-Control-Allow-Headers", "Content-Range, Content-Disposition, Content-Type, ETag")
        request.Write(writer)
}

func main() {
        log.Println("starting server, listening on port " + getHttpPort())
        http.HandleFunc("/", EchoHandler)
        http.ListenAndServe(":"+getHttpPort(), nil)
}
