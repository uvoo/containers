FROM debian:trixie-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive
ARG PGSQL_HTTP_VER=1.7.0

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        make \
        g++ \
        unzip \
        libcurl4-openssl-dev && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc -o /etc/apt/keyrings/postgresql.asc && \
    echo "deb [signed-by=/etc/apt/keyrings/postgresql.asc] https://apt.postgresql.org/pub/repos/apt trixie-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends postgresql-server-dev-18 && \
    curl -fsSL -o pgsql-http.zip "https://github.com/pramsey/pgsql-http/archive/refs/tags/v${PGSQL_HTTP_VER}.zip" && \
    unzip -q pgsql-http.zip && \
    cd pgsql-http-${PGSQL_HTTP_VER} && \
    make && \
    make install

FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive
ARG PGSQL_HTTP_VER=1.7.0
ENV PGSQL_HTTP_VER="${PGSQL_HTTP_VER}"
ENV PATH="/usr/lib/postgresql/18/bin:$PATH"
ENV PGDATA="/var/lib/postgresql/data"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        openssh-client \
        python3-paramiko \
        python3-winrm \
        python3-scp \
        libcurl4 && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc -o /etc/apt/keyrings/postgresql.asc && \
    echo "deb [signed-by=/etc/apt/keyrings/postgresql.asc] https://apt.postgresql.org/pub/repos/apt trixie-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor -o /etc/apt/keyrings/timescaledb.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/timescaledb.gpg] https://packagecloud.io/timescale/timescaledb/debian trixie main" > /etc/apt/sources.list.d/timescaledb.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        postgresql-18 \
        postgresql-client-18 \
        postgresql-plpython3-18 \
        postgresql-18-cron \
        timescaledb-2-postgresql-18 && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p "$PGDATA" /var/run/postgresql && \
    chown -R postgres:postgres "$PGDATA" /var/run/postgresql && \
    chmod 2777 /var/run/postgresql

COPY --from=builder /usr/lib/postgresql/18/lib/http.so /usr/lib/postgresql/18/lib/
COPY --from=builder /usr/share/postgresql/18/extension/http* /usr/share/postgresql/18/extension/

USER postgres
WORKDIR /var/lib/postgresql

EXPOSE 5432
CMD ["postgres"]
