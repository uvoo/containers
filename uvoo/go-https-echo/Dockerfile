FROM golang:1.22.1-bookworm
WORKDIR /usr/src/app
COPY go-https-echo.go ./
RUN go build go-https-echo.go && mv go-https-echo /usr/local/bin/

CMD ["go-https-echo"]
