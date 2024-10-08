#!/bin/bash
set -e
# git clone -b 6.0 https://github.com/zabbix/zabbix
# cp -rp zabbix/templates/db/postgresql ./
rm -rf postgresql
git clone --depth 1 --branch 6.0.34 https://github.com/zabbix/zabbix
cp -rp zabbix/templates/db/postgresql ./
rm -rf zabbix
