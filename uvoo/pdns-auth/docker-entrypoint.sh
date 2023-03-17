#!/bin/bash
set -eu
 
# sqlite3 /app/pdns.sqlite3 < /usr/share/pdns-backend-sqlite3/schema/schema.sqlite3.sql
# chmod 0777 /app/pdns.sqlite3

# cd /app/cnf/
cd /etc/powerdns/
envtpl --keep-template pdns.conf.tpl

if psql -lqt | cut -d \| -f 1 | grep -qw ${PGDATABASE}; then
  records_lc=$(psql -qtc "\d" | grep records | wc -l)
  initdb=no
  if [ $records_lc -eq 0 ]; then
    initdb=yes
  fi

  if [ "$initdb" = "yes" ]; then
    echo "Initializing empty database ${PGDATABASE}."
    psql -a -f /usr/share/pdns-backend-pgsql/schema/schema.pgsql.sql
  fi 
else
  echo "Database ${PGDATABASE} does not exists!"
  exit 1
fi

exec /usr/sbin/pdns_server --config-dir=/etc/powerdns --guardian=no --daemon=no --disable-syslog --log-timestamp=no --write-pid=no --zone-cache-refresh-interval=10
