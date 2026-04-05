# ---- Build stage: compile pgsql-http against PG 18 ----
# FIX: Added "AS builder"
FROM ghcr.io/cloudnative-pg/postgresql:18.3-standard-trixie AS builder
# FROM ghcr.io/cloudnative-pg/postgresql:18.1-standard-bookworm AS builder

ENV DEBIAN_FRONTEND=noninteractive
ARG PGSQL_HTTP_VER=1.7.0

USER root

# Install build dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    postgresql-server-dev-18 \
    libcurl4-openssl-dev \
    unzip \
    ca-certificates \
    curl \
    make \
    g++

WORKDIR /tmp/build

RUN set -eux; \
    curl -fsSL -o pgsql-http.zip "https://github.com/pramsey/pgsql-http/archive/refs/tags/v${PGSQL_HTTP_VER}.zip"; \
    unzip -q pgsql-http.zip; \
    cd pgsql-http-${PGSQL_HTTP_VER}; \
    make; \
    make install

# ---- Runtime stage: PG + plpython + http extension artifacts ----
# FROM ghcr.io/cloudnative-pg/postgresql:18.1-standard-trixie
FROM ghcr.io/cloudnative-pg/postgresql:18.1-standard-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ARG PGSQL_HTTP_VER=1.7.0
# Good practice: Persist the version in env for debugging
ENV PGSQL_HTTP_VER="${PGSQL_HTTP_VER}"

USER root

# Combined installation to reduce layers
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        # Python & System utils
        gnupg \
        ca-certificates \
        curl \
        openssh-client \
        postgresql-plpython3-18 \
        python3-paramiko \
        python3-winrm \
        python3-scp \
        # Runtime lib only (swapped -dev for libcurl4)
        libcurl4 \
        postgresql-18-cron \
    ; \
    # Setup TimescaleDB Repo
    echo "deb https://packagecloud.io/timescale/timescaledb/debian bookworm main" \
        > /etc/apt/sources.list.d/timescaledb.list; \
    curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
        | gpg --dearmor > /etc/apt/trusted.gpg.d/timescaledb.gpg; \
    # Install Timescale
    apt-get update; \
    apt-get install -y --no-install-recommends \
        timescaledb-2-postgresql-18 \
        postgresql-client-18 \
    ; \
    # Clean up
    rm -rf /var/lib/apt/lists/*

# Copy artifacts from "builder"
COPY --from=builder /usr/lib/postgresql/18/lib/http.so /usr/lib/postgresql/18/lib/
COPY --from=builder /usr/share/postgresql/18/extension/http* /usr/share/postgresql/18/extension/

USER 26
