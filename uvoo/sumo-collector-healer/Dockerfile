FROM ubuntu:latest

WORKDIR /app

RUN apt-get update && apt-get install -y ansible gettext-base python3 python3-requests

COPY app.py .
COPY main.sh .
COPY rcmd .
COPY vars.yaml.envsubst .
COPY playbookSumoCollector.yaml .
# ENTRYPOINT [ "python3", "-u", "app.py" ]
ENTRYPOINT [ "python3", "app.py" ]
