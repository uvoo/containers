# ---- Build stage: compile pgsql-http against PG 17 ----
FROM ghcr.io/cloudnative-pg/postgresql:17.5-bookworm AS builder
ENV DEBIAN_FRONTEND=noninteractive
ARG PGSQL_HTTP_VER=1.7.0

# Become root before using apt
USER root

# Tools + PG dev headers for v17 (PGXS)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    postgresql-server-dev-17 \
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
FROM ghcr.io/cloudnative-pg/postgresql:17.5-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ARG PGSQL_HTTP_VER=1.7.0
ENV PGSQL_HTTP_VER="${PGSQL_HTTP_VER}"

# Become root to install packages/copy files
USER root

# Install PL/Python, pg_cron & http libcurl dep for PG17 (runtime dep only)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends postgresql-plpython3-17 \
    libcurl4-openssl-dev \
    postgresql-17-cron; \
    rm -rf /var/lib/apt/lists/*

# Install dependencies and TimescaleDB
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        gnupg wget ca-certificates \
    ; \
    echo "deb https://packagecloud.io/timescale/timescaledb/debian bookworm main" \
        > /etc/apt/sources.list.d/timescaledb.list; \
    wget -qO - https://packagecloud.io/timescale/timescaledb/gpgkey \
        | gpg --dearmor > /etc/apt/trusted.gpg.d/timescaledb.gpg; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        timescaledb-2-postgresql-17 \
    ; \
    rm -rf /var/lib/apt/lists/*

# Copy only the built extension artifacts from builder
# (shared library + extension control/SQL files)
COPY --from=builder /usr/lib/postgresql/17/lib/http.so /usr/lib/postgresql/17/lib/
COPY --from=builder /usr/share/postgresql/17/extension/http* /usr/share/postgresql/17/extension/

# Drop privileges back to the postgres UID used by CNPG images
USER 26

# (Optional) Show the version at build time for traceability
# docker build --build-arg PGSQL_HTTP_VER=1.7.0 .

