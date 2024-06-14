# Stage 1: Build the Go application
FROM golang:1.21 as builder


# Set the working directory inside the container
WORKDIR /app

# Copy go.mod and go.sum files
COPY go.mod go.sum ./

# Download all dependencies
RUN go mod download

# Copy the source code
COPY . .

# Build the Go application
RUN go build -o mtr_probe .

# Stage 2: Build the final image
FROM debian:bookworm-slim
ENV BLACKBOX_EXPORTER_VERSION="0.25.0"

# Install MTR and necessary utilities
RUN apt-get update && apt-get install -y mtr-tiny wget ca-certificates iproute2

# Install Blackbox Exporter
RUN wget https://github.com/prometheus/blackbox_exporter/releases/download/v${BLACKBOX_EXPORTER_VERSION}/blackbox_exporter-${BLACKBOX_EXPORTER_VERSION}.linux-amd64.tar.gz \
    && tar -xzf blackbox_exporter-${BLACKBOX_EXPORTER_VERSION}.linux-amd64.tar.gz \
    && mv blackbox_exporter-${BLACKBOX_EXPORTER_VERSION}.linux-amd64/blackbox_exporter /usr/local/bin/ \
    && rm -rf blackbox_exporter-${BLACKBOX_EXPORTER_VERSION}.linux-amd64*

# Create a new group for ping and add the nobody user to it
# RUN adduser -D -u 1000 app
RUN useradd -r -u 1000 -s /bin/false app 
# RUN addgroup -g 9999 ping && addgroup nobody ping && addgroup app ping
# RUN addgroup -g 9999 ping
RUN groupadd ping -g 9999
RUN usermod -aG ping app 

# Set the necessary permissions on the blackbox_exporter binary
RUN set -x
RUN chgrp ping /usr/local/bin/blackbox_exporter && chmod g+rx /usr/local/bin/blackbox_exporter
# COPY default.config.yml /etc/blackbox_exporter/config.yml

# Copy the Go application binary
COPY --from=builder /app/mtr_probe /usr/local/bin/mtr_probe

# Create a blackbox exporter config
COPY blackbox.yml /etc/blackbox_exporter/config.yml

# Expose ports for both services
EXPOSE 9115 9116

USER 1000 
STOPSIGNAL SIGUSR1
# Start both the Go application and Blackbox Exporter
CMD ["sh", "-c", "mtr_probe & blackbox_exporter --config.file=/etc/blackbox_exporter/config.yml"]
