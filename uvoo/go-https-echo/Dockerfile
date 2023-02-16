FROM golang:bullseye
WORKDIR /usr/src/app
COPY https-echo.go ./
RUN go build https-echo.go && mv https-echo /usr/local/bin/

CMD ["https-echo"]
