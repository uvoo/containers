#!/bin/bash
set -eu
 
# sqlite3 /app/pdns.sqlite3 < /usr/share/pdns-backend-sqlite3/schema/schema.sqlite3.sql
# chmod 0777 /app/pdns.sqlite3

cd /app/cnf/
envtpl --keep-template pdns.conf.tpl

if psql -lqt | cut -d \| -f 1 | grep -qw ${PGDATABASE}; then
  records_lc=$(psql -qtc "\d" | grep records | wc -l)
  initdb=no
  if [ $records_lc -gt 1 ]; then
    initdb=yes
  fi

  if [ initdb = "yes" ]; then
    # echo "Database ${PGDATABASE} exists!"
    echo "Initializing empty database ${PGDATABASE}."
    # echo "Beginning schema import!"
    # psql < /usr/share/pdns-backend-pgsql/schema/schema.pgsql.sql
    psql -a -f /usr/share/pdns-backend-pgsql/schema/schema.pgsql.sql
  # $? is 0
# curl -v -H 'X-API-Key: changeme' http://127.0.0.1:8081/api/v1/servers/localhost | jq .
# curl -v -H 'X-API-Key: changeme' http://127.0.0.1:8081/api/v1/servers/localhost/zones | jq .
  fi 
else
  echo "Database ${PGDATABASE} does not exists!"
  exit 1
    # ruh-roh
    # $? is 1
fi

# pdnsutil --config-dir /app/cnf/ create-zone uvoo.com
# pdnsutil create-zone foo.example.com
# pdnsutil add-record foo.example.com @ A 192.168.1.2
# pdnsutil create-zone uvoo.io
# pdnsutil add-record uvoo.io www A 192.168.1.23
exec /usr/sbin/pdns_server --config-dir=/app/cnf --guardian=no --daemon=no --disable-syslog --log-timestamp=no --write-pid=no --zone-cache-refresh-interval=10
