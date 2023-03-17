FROM ubuntu:lunar
# FROM ubuntu:jammy
MAINTAINER Jeremy Kenneth Busk <jeremybusk@gmail.com>

ARG username=app

RUN useradd -ms /bin/bash -d /$username $username
WORKDIR /$username
RUN mkdir -p /etc/powerdns && mkdir -p /var/run/pdns

COPY pdns.conf.tpl /etc/powerdns/pdns.conf.tpl

RUN apt-get update
# RUN apt-get -y install pdns-backend-pgsql pdns-backend-sqlite3 postgresql-client sqlite3 pdns-backend-bind pdns-backend-geoip
RUN apt-get -y install pdns-backend-pgsql pdns-backend-sqlite3 postgresql-client sqlite3 curl jq dnsutils python3-pip
RUN python3 -m pip install --break-system-packages envtpl
RUN python3 -m pip cache remove *
# python3-full
# python3 -m venv venv
# . venv/bin/activate
# deactivate
RUN apt-get clean

ADD docker-entrypoint.sh /
# ADD pgsql-schema.sql /etc/pdns/
# ADD sqlite-schema.sql /etc/pdns/

EXPOSE 8053/udp
EXPOSE 8053/tcp
EXPOSE 8081/tcp

RUN chown -R $username /etc/powerdns /var/run/pdns

USER $username 

ENTRYPOINT ["/docker-entrypoint.sh"]
# ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/sbin/pdns_server-startup"]
