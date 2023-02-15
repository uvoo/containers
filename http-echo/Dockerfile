FROM golang:bullseye
WORKDIR /usr/src/app
COPY http-echo.go ./
RUN go build http-echo.go && mv http-echo /usr/local/bin/http-echo

CMD ["http-echo"]
