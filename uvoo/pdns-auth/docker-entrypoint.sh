#!/bin/bash
set -eu
 
sqlite3 /app/pdns.sqlite3 < /usr/share/pdns-backend-sqlite3/schema/schema.sqlite3.sql
chmod 0777 /app/pdns.sqlite3

pdnsutil create-zone foo.example.com
pdnsutil add-record foo.example.com @ A 192.168.1.2
pdnsutil create-zone uvoo.io
pdnsutil add-record uvoo.io www A 192.168.1.23
exec /usr/sbin/pdns_server --config-dir=/app/cnf --guardian=no --daemon=no --disable-syslog --log-timestamp=no --write-pid=no --zone-cache-refresh-interval=10
