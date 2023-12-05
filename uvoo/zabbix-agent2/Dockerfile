# syntax=docker/dockerfile:1
# https://github.com/zabbix/zabbix-docker/tree/6.0/Dockerfiles/agent2/alpine
# 6.0.9-alpine
# FROM zabbix/zabbix-agent2:6.0-alpine-latest 
# FROM zabbix/zabbix-agent2:6.0.9-alpine
FROM zabbix/zabbix-agent2:6.0.23-ubuntu
SHELL ["/bin/bash", "-c"]
USER root
ARG INTERNAL_ROOTCA_CRTS_URL

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
    ca-certificates
    # gcc \

RUN if [[ -v INTERNAL_ROOTCA_CRTS_URL ]] ; then curl -s ${INTERNAL_ROOTCA_CRTS_URL} | sudo awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{ if(/BEGIN CERTIFICATE/){a++}; out="/usr/local/share/ca-certificates/internalrootca"a".crt"; print >out}'; sudo update-ca-certificates; fi

ADD ./postgresql/postgresql /var/lib/zabbix/postgresql
ADD ./postgresql/template_db_postgresql.conf /etc/zabbix/zabbix_agent2.d/
RUN chown -R zabbix /var/lib/zabbix/postgresql

EXPOSE 10050/TCP
WORKDIR /var/lib/zabbix
# COPY ["docker-entrypoint.sh", "/usr/bin/"]
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/bin/docker-entrypoint.sh"]
USER 1997
CMD ["/usr/sbin/zabbix_agent2", "--foreground", "-c", "/etc/zabbix/zabbix_agent2.conf"]
