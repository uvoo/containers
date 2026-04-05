# ---- Build stage: compile pgsql-http against PG 18 ----
FROM ghcr.io/cloudnative-pg/postgresql:18.3-standard-trixie AS builder

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
FROM ghcr.io/cloudnative-pg/postgresql:18.3-standard-trixie

ENV DEBIAN_FRONTEND=noninteractive
ARG PGSQL_HTTP_VER=1.7.0
# Good practice: Persist the version in env for debugging
ENV PGSQL_HTTP_VER="${PGSQL_HTTP_VER}"

USER root

# Combined installation to reduce layers
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        gnupg \
        ca-certificates \
        curl \
        openssh-client \
        postgresql-plpython3-18 \
        python3-paramiko \
        python3-winrm \
        python3-scp \
        libcurl4 \
        postgresql-18-cron \
        postgresql-common \
    ; \
    /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
        | gpg --dearmor -o /etc/apt/keyrings/timescaledb.gpg; \
    chmod a+r /etc/apt/keyrings/timescaledb.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/timescaledb.gpg] https://packagecloud.io/timescale/timescaledb/debian trixie main" \
        > /etc/apt/sources.list.d/timescaledb.list; \
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
