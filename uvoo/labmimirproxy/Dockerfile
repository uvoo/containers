FROM golang:latest AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o mimirproxy .

FROM alpine:latest

RUN apk add --no-cache ca-certificates && update-ca-certificates

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

COPY --from=builder /app/mimirproxy .

RUN chmod +x mimirproxy

USER appuser

EXPOSE 8080

CMD ["./mimirproxy"]

