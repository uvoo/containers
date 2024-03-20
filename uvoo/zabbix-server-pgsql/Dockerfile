# syntax=docker/dockerfile:1
FROM zabbix/zabbix-server-pgsql:6.0.27-ubuntu
SHELL ["/bin/bash", "-ec"]
USER root
ARG INTERNAL_ROOTCA_CRTS_URL

ADD ./alertscripts /usr/lib/zabbix/alertscripts
ADD ./externalscripts /usr/lib/zabbix/externalscripts
ADD ./mibs /var/lib/zabbix/mibs
# RUN chown -R zabbix:zabbix /usr/lib/zabbix/externalscripts /usr/lib/zabbix/alertscripts
RUN chown -R zabbix /usr/lib/zabbix/externalscripts /usr/lib/zabbix/alertscripts
# RUN chmod -R +x /usr/lib/zabbix/externalscripts/* /usr/lib/zabbix/alertscripts/*
# COPY ./alertscripts /usr/lib/zabbix/alertscripts
# COPY ./externalscripts /usr/lib/zabbix/externalscripts
# COPY alertscripts /usr/lib/zabbix/alertscripts
# COPY externalscripts /usr/lib/zabbix/externalscripts

# start custom

RUN set -eux && \
    apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
    dnsutils \
    curl \
    mtr \
    netcat-openbsd \
    python3 \
    python3-pip \
    libffi-dev \
    libgit2-dev \
    python3-dev \
    sudo \
    gnupg2 \
    gcc \
    ca-certificates

RUN if [[ -v INTERNAL_ROOTCA_CRTS_URL ]] ; then curl -s ${INTERNAL_ROOTCA_CRTS_URL} | sudo awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{ if(/BEGIN CERTIFICATE/){a++}; out="/usr/local/share/ca-certificates/internalrootca"a".crt"; print >out}'; sudo update-ca-certificates; fi

RUN curl -SL https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
RUN curl -SL https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list

  # optional: for bcp and sqlcmd
  # sudo ACCEPT_EULA=Y apt-get install -y mssql-tools
  # echo 'export PATH="/home/busk/.local/bin:/home/busk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/usr/local/go/bin:/home/busk/.local/bin:/home/busk/go/bin:/opt/mssql-tools/bin"' >> ~/.bashrc
  # source ~/.bashrc
  # # optional: for unixODBC development headers
  # sudo apt-get install -y unixodbc-dev
RUN set -eux && \
    apt-get -y update && \
    ACCEPT_EULA=Y DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
    odbcinst \
    odbcinst1debian2 \
    unixodbc \
    msodbcsql17
    # build-essential \
    # libssh2-1-dev \
RUN pip3 install vonage
    # pip3 install --no-cache-dir gitfs
# mkdir -p /var/lib/gitfs
# end custom

EXPOSE 10051/TCP

WORKDIR /var/lib/zabbix

VOLUME ["/var/lib/zabbix/snmptraps", "/var/lib/zabbix/export"]

# COPY ["docker-entrypoint.sh", "/usr/bin/"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/bin/docker-entrypoint.sh"]

USER 1997

CMD ["/usr/sbin/zabbix_server", "--foreground", "-c", "/etc/zabbix/zabbix_server.conf"]
