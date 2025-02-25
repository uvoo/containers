# syntax=docker/dockerfile:1
FROM zabbix/zabbix-server-pgsql:6.0.39-ubuntu
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
    curl \
    ca-certificates

RUN if [[ -v INTERNAL_ROOTCA_CRTS_URL ]] ; then curl -s ${INTERNAL_ROOTCA_CRTS_URL} | sudo awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{ if(/BEGIN CERTIFICATE/){a++}; out="/usr/local/share/ca-certificates/internalrootca"a".crt"; print >out}'; sudo update-ca-certificates; fi

# MSSQL
# if ! [[ "18.04 20.04 22.04 24.04" == *"$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2)"* ]];
# then
#     echo "Ubuntu $(grep VERSION_ID /etc/os-release | cut -d '"' -f 2) is not currently supported.";
#     exit;
# fi

RUN set -eu \
  curl -sSL -O https://packages.microsoft.com/config/ubuntu/$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2)/packages-microsoft-prod.deb \
  sudo dpkg -i packages-microsoft-prod.deb \
  rm packages-microsoft-prod.deb \
  sudo apt-get update \
  sudo ACCEPT_EULA=Y apt-get install -y msodbcsql18 \
  sudo ACCEPT_EULA=Y apt-get install -y mssql-tools18 \
  echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
  # source ~/.bashrc \
  # sudo apt-get install -y unixodbc-dev \


# RUN pip3 install vonage
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
