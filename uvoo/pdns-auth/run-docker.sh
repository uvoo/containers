#!/bin/bash
set -eu

docker build . --tag=pdns-auth-test
docker rm -f pdns-auth-test || true
docker run -d -p 5353:53/udp -p 5353:53/tcp --restart unless-stopped --name=foo \
--volume=$PWD/pdns.conf:/etc/powerdns/pdns.conf:z  pdns-auth-test 
# --volume=$PWD/pdns.conf:/etc/powerdns/pdns.conf:z powerdns/pdns-auth-45:4.5.2
