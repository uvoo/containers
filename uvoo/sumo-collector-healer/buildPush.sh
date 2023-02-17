#!/usr/bin/env bash
set -e
release=latest
docker build --tag uvoo/sumo-collector-healer:$release .
# docker login
docker push uvoo/sumo-collector-healer:$release 
