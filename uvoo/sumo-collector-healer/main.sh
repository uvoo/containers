#!/usr/bin/env bash
set -e
echo "Setting vars.yaml from envs"
envsubst < vars.yaml.envsubst > vars.yaml
echo "Starting application"
python3 app.py -i ${INTERVAL_SECONDS} -d ${DOMAIN}
