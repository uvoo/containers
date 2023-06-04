# syntax=docker/dockerfile:1
# https://github.com/zabbix/zabbix-docker/tree/6.0/Dockerfiles/agent2/alpine
# 6.0.9-alpine
# FROM zabbix/zabbix-agent2:6.0-alpine-latest 
# FROM zabbix/zabbix-agent2:6.0.9-alpine
FROM zabbix/zabbix-agent2:6.0.18-ubuntu
USER root

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
    gnupg2 \
    ca-certificates
    # gcc \

ADD internal_ca_root.crt /usr/local/share/ca-certificates/internal_ca_root.crt
RUN chmod 644 /usr/local/share/ca-certificates/internal_ca_root.crt && update-ca-certificates

ADD ./postgresql/postgresql /var/lib/zabbix/postgresql
ADD ./postgresql/template_db_postgresql.conf /etc/zabbix/zabbix_agent2.d/
RUN chown -R zabbix /var/lib/zabbix/postgresql

EXPOSE 10050/TCP
WORKDIR /var/lib/zabbix
# COPY ["docker-entrypoint.sh", "/usr/bin/"]
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/bin/docker-entrypoint.sh"]
USER 1997
CMD ["/usr/sbin/zabbix_agent2", "--foreground", "-c", "/etc/zabbix/zabbix_agent2.conf"]
