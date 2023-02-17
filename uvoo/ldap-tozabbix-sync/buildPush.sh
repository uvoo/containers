#!/usr/bin/env bash
set -e
release=latest
docker build --tag uvoo/ldap-tozabbix-sync:$release .
# docker login
docker push uvoo/ldap-tozabbix-sync:$release 
