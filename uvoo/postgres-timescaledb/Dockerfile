# FROM postgres:16-bookworm
FROM ghcr.io/cloudnative-pg/postgresql:16.0
USER root
ENV PGSQL_HTTP_VERSION=1.6.0
RUN set -eux && \
    apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
    gnupg2 \
    sudo \
    ca-certificates \
    lsb-release \
    wget \
    curl \
    postgresql-server-dev-16 \
    libcurl4-openssl-dev \
    git \
    make \
    g++ \
    llvm-13-linker-tools \
    clang \
    clang-tools \
    llvm \
    gcc
    # clang-11 \
    # build-essential \
    # /usr/lib/llvm-11/bin/llvm-lto
    # build-essential \
# sudo apt-get install llvm
# sudo apt-get install clang
# sudo apt-get install clang-tools

# pgsql-http
RUN mkdir -p src
RUN cd src && \
  git clone --depth 1 --branch v${PGSQL_HTTP_VERSION} https://github.com/pramsey/pgsql-http.git && \
  cd pgsql-http && \
  make && \
  sudo make install
RUN rm -rf src

# Timescale
RUN echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" | sudo tee /etc/apt/sources.list.d/timescaledb.list
RUN wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo apt-key add -
RUN echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
RUN sudo apt-get update
RUN sudo apt-get -y install timescaledb-2-postgresql-16
    
RUN set -eux && \
    sudo apt-get remove -y lsb-release wget \
    && 	rm -fr /tmp/* \
    && 	rm -rf /var/lib/apt/lists/*

RUN usermod -u 26 postgres
USER 26
