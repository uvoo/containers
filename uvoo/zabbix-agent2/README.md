Zabbix agent2 ubuntu with postgresql support

https://github.com/zabbix/zabbix-docker/blob/6.2/Dockerfiles/agent2/ubuntu/Dockerfile

https://github.com/zabbix/zabbix/tree/master/templates/db/postgresql
 
https://github.com/zabbix/zabbix-docker/tree/6.0/Dockerfiles/agent2/alpine


Getting current files
```
rm -rf postgresql
git clone --depth 1 --branch 6.0.10 https://github.com/zabbix/zabbix
cp -rp zabbix/templates/db/postgresql ./
rm -rf zabbix
```
