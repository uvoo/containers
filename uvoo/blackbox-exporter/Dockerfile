# Use a lightweight base image
FROM alpine:latest

# Install necessary packages
RUN apk add --no-cache \
    libcap \
    curl

# Download and install Blackbox Exporter
ENV BLACKBOX_EXPORTER_VERSION 0.25.0
RUN wget https://github.com/prometheus/blackbox_exporter/releases/download/v${BLACKBOX_EXPORTER_VERSION}/blackbox_exporter-${BLACKBOX_EXPORTER_VERSION}.linux-amd64.tar.gz && \
    tar -xzf blackbox_exporter-${BLACKBOX_EXPORTER_VERSION}.linux-amd64.tar.gz && \
    mv blackbox_exporter-${BLACKBOX_EXPORTER_VERSION}.linux-amd64/blackbox_exporter /usr/local/bin/blackbox_exporter && \
    rm -rf blackbox_exporter-${BLACKBOX_EXPORTER_VERSION}.linux-amd64*

# Set the capability to allow ICMP
RUN setcap cap_net_raw+ep /usr/local/bin/blackbox_exporter

# Create a user with UID 1000
RUN adduser -D -u 1000 nonrootuser

# Create a configuration file for Blackbox Exporter
COPY default.config.yml /etc/blackbox_exporter/config.yml

# Set the permissions
RUN chown nonrootuser:nonrootuser /etc/blackbox_exporter/config.yml
RUN ln -s /etc/blackbox_exporter/config.yml /config/blackbox.yaml

# Expose the port
EXPOSE 9115

# Run the exporter as the non-root user
USER nonrootuser

# Command to run the Blackbox Exporter
# CMD ["blackbox_exporter", "--config.file=/etc/blackbox_exporter/config.yml"]

CMD ["blackbox_exporter", "--config.file=/etc/blackbox_exporter/config.yml", "--log.level=debug"]
