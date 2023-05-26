# Dockerfile Ideas
- https://github.com/camptocamp/docker-rsyslog-bin/blob/master/Dockerfile

https://help.sumologic.com/docs/send-data/hosted-collectors/cloud-syslog-source/rsyslog/

https://github.com/manics/rsyslog-stdout-docker/tree/master


# Other options

# Syslog Sumo Collector in k8s

## Environment Variables
https://hub.docker.com/r/sumologic/collector/#collector-environment-variables


https://github.com/SumoLogic/sumologic-collector-docker/blob/master/example/sumo-sources.json.syslog-tcp.example

https://help.sumologic.com/docs/send-data/use-json-configure-sources/

## Test
```
logger --udp --port 514 -n 10.x.x.x "test message"
```

## Query
```
_collector="collector_container-sumo-syslog-collector"
```
