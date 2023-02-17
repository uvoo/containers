# zabbix-server-pgsql

Uses Ubuntu 20.04 base from https://hub.docker.com/r/zabbix/zabbix-server-pgsql

Adds enhanced features for Zabbix Docker Server Postgres:

This is mainly for adding external scripts/commands

- Python3 for external scripts
- Nexmo voice python package
- Microsoft SQL Support
- curl
- Netcat

```
docker run -it --entrypoint /bin/bash uvoo/zabbix-server-pgsql:6.0.4-ubuntu
```
