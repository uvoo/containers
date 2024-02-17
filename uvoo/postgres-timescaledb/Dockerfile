FROM postgres:16-bookworm
RUN set -eux && \
    apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
    gnupg2 \
    sudo \
    ca-certificates \
    lsb-release \
    wget

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
