#!/usr/bin/env bash
set -eu

echo "Style check."
pip install flake8 && flake8 app.py

echo "Build and push docker container to Dockerhub."
release=6.0.18
docker build --tag uvoo/monitor-utils:latest --tag uvoo/monitor-utils:$release .
echo Push to docker repo in 5 seconds; sleep 5
echo $DOCKERHUB_PASSWORD | docker login --username $DOCKERHUB_USERNAME --password-stdin
docker push uvoo/monitor-utils:$release
docker push uvoo/monitor-utils:latest
docker logout
