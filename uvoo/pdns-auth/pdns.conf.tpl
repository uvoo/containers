webserver-port=8081
api={{ API | default("no") }}
api-key={{ APIKEY | default("PleaseDontUseThis") }}
zone-cache-refresh-interval=30
consistent-backends=yes # https://doc.powerdns.com/authoritative/settings.html#setting-consistent-backends
local-address=0.0.0.0:8053
enable-lua-records={{ ENABLE_LUA_RECORDS | default("yes") }}
lua-health-checks-interval={{ LUA_HEALTH_CHECKS_INTERVAL | default("5") }}

log-dns-details={{ LOG_DNS_DETAILS | default("no") }}
log-dns-queries={{ LOG_DNS_QUERIES | default("no") }}
loglevel={{ LOGLEVEL | default("4") }}

webserver=yes
webserver-port=8081
webserver-address=0.0.0.0
webserver-allow-from=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16

{% if DBTYPE == "pgsql" %}
launch=gpgsql
gpgsql-host={{ PGHOST }}
gpgsql-port={{ PGPORT | default(5432) }} 
gpgsql-dbname={{ PGDATABASE | default("pdns") }}
gpgsql-user={{ PGUSER | default("pdns") }}
gpgsql-password={{ PGPASSWORD }}
gpgsql-dnssec={ GPGSQL_DNSSEC | default("yes") }}
{% endif -%}

{% if DBTYPE == "sqlite3" %}
launch=gsqlite3
# gsqlite3-database=/var/lib/sqlite/sqlite.db
gsqlite3-database=/app/pdns.sqlite3
zone-cache-refresh-interval=10
consistent-backends=yes # https://doc.powerdns.com/authoritative/settings.html#setting-consistent-backends
# local-address=0.0.0.0:5353
local-address=0.0.0.0:53
# security-poll-suffix=
# include-dir=/etc/powerdns/pdns.d
# launch=
{% endif -%}

{% if DBTYPE == "mysql" %}
# foo
{% endif -%}

# Notes
# enable-gss-tsig={{ TSIG | default("yes") }}
