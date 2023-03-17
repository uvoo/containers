FROM ubuntu:lunar
# FROM ubuntu:jammy
MAINTAINER Jeremy Kenneth Busk <jeremybusk@gmail.com>

WORKDIR /app

COPY pdns.conf.tpl /app/cnf/pdns.conf.tpl

RUN apt-get update
# RUN apt-get -y install pdns-backend-pgsql pdns-backend-sqlite3 postgresql-client sqlite3 pdns-backend-bind pdns-backend-geoip
RUN apt-get -y install pdns-backend-pgsql pdns-backend-sqlite3 postgresql-client sqlite3 curl jq dnsutils python3-pip
RUN python3 -m pip install --break-system-packages envtpl
RUN pyton3 -m pip cache remove *
# python3-full
# python3 -m venv path/to/venv.
RUN apt-get clean

ADD docker-entrypoint.sh /
# ADD pgsql-schema.sql /etc/pdns/
# ADD sqlite-schema.sql /etc/pdns/

EXPOSE 53/udp
EXPOSE 53/tcp
EXPOSE 8081/tcp

ENTRYPOINT ["/docker-entrypoint.sh"]
# ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/sbin/pdns_server-startup"]
