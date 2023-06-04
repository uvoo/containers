Zabbix agent2 ubuntu with postgresql support

https://github.com/zabbix/zabbix-docker/blob/6.2/Dockerfiles/agent2/ubuntu/Dockerfile

https://github.com/zabbix/zabbix/tree/master/templates/db/postgresql
 
https://github.com/zabbix/zabbix-docker/tree/6.0/Dockerfiles/agent2/alpine

## Updating
```
grep 6.0.18 *
# update all instances with new version i.e. 6.0.19
./updateFiles.sh
git add ., commit push
```

## Internal CA Root Cert
This is created in /main.sh and is optional if you actually want it.


Getting current files
```
rm -rf postgresql
git clone --depth 1 --branch 6.0.10 https://github.com/zabbix/zabbix
cp -rp zabbix/templates/db/postgresql ./
rm -rf zabbix
```
