#!/bin/bash
set -eu
DOCKER_TAG="uvoo/pdns-auth"
DOCKER_NAME="pdns-auth"
docker build . --tag=$DOCKER_TAG
docker rm -f $DOCKER_NAME || true
# docker run -d -p 5353:53/udp -p 5353:53/tcp --restart unless-stopped --name=$DOCKER_NAME \
docker run -d -p 8081:8081 -p 8053:8053/udp -p 8053:8053/tcp --name=$DOCKER_NAME \
-e API=yes \
-e APIKEY="$APIKEY" \
-e PGPASSWORD="$PGPASSWORD" \
-e ENABLE_LUA_RECORDS=yes \
-e LUA_HEALTH_CHECKS_INTERVAL=30 \
-e LOG_DNS_DETAILS=yes \
-e LOG_DNS_QUERIES=yes \
-e LOGLEVEL=7 \
-e DBTYPE=pgsql \
-e PGHOST=$PGHOST \
-e PGUSER=pdns \
-e PGDATABASE=pdns \
-e PGSSLMODE=prefer \
$DOCKER_TAG

# --volume=$PWD/pdns.conf:/etc/powerdns/pdns.conf:z $DOCKER_TAG
# --volume=$PWD/pdns.conf:/etc/powerdns/pdns.conf:z $DOCKER_TAG
# --volume=$PWD/pdns.conf:/etc/powerdns/pdns.conf:z powerdns/pdns-auth-45:4.5.2
# export PGSSLMODE=require
# -e PGHOST=pgbouncer1.postgres.svc \
