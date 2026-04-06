# Build pgsql-http against PostgreSQL 18
FROM postgres:18-trixie AS builder

ARG PGSQL_HTTP_VER=1.7.0
ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
        make \
        g++ \
        libcurl4-openssl-dev \
        postgresql-server-dev-18; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    curl -fsSL -o /tmp/pgsql-http.zip \
      "https://github.com/pramsey/pgsql-http/archive/refs/tags/v${PGSQL_HTTP_VER}.zip"; \
    unzip -q /tmp/pgsql-http.zip -d /tmp; \
    cd /tmp/pgsql-http-${PGSQL_HTTP_VER}; \
    make; \
    make install
    # pgsql-http upstream documents build/install this way
    # https://github.com/pramsey/pgsql-http

# Runtime image
FROM postgres:18-trixie

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        openssh-client \
        python3-paramiko \
        python3-winrm \
        python3-scp; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
      | gpg --dearmor -o /etc/apt/keyrings/timescaledb.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/timescaledb.gpg] https://packagecloud.io/timescale/timescaledb/debian trixie main" \
      > /etc/apt/sources.list.d/timescaledb.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        postgresql-18-cron \
        postgresql-plpython3-18 \
        timescaledb-2-postgresql-18; \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/lib/postgresql/18/lib/http.so /usr/lib/postgresql/18/lib/
COPY --from=builder /usr/share/postgresql/18/extension/http* /usr/share/postgresql/18/extension/

# Optional: initialization scripts
COPY docker-initdb/ /docker-entrypoint-initdb.d/

EXPOSE 5432
