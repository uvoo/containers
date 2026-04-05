#!/bin/bash
set -e

if [ ! -f "$PGDATA/PG_VERSION" ]; then
  eval "initdb -D \"$PGDATA\" ${POSTGRES_INITDB_ARGS}"

  AUTH_METHOD=${POSTGRES_HOST_AUTH_METHOD:-scram-sha256}
  echo "host all all all $AUTH_METHOD" >> "$PGDATA/pg_hba.conf"

  pg_ctl -D "$PGDATA" -o "-c listen_addresses='localhost'" -w start

  DB_USER=${POSTGRES_USER:-postgres}
  DB_NAME=${POSTGRES_DB:-$DB_USER}

  if [ "$DB_USER" != 'postgres' ]; then
    psql -v ON_ERROR_STOP=1 --username "postgres" --dbname "postgres" <<-EOSQL
      CREATE ROLE "$DB_USER" WITH LOGIN SUPERUSER PASSWORD '${POSTGRES_PASSWORD}';
EOSQL
  elif [ -n "$POSTGRES_PASSWORD" ]; then
    psql -v ON_ERROR_STOP=1 --username "postgres" --dbname "postgres" <<-EOSQL
      ALTER ROLE postgres WITH PASSWORD '${POSTGRES_PASSWORD}';
EOSQL
  fi

  if [ "$DB_NAME" != 'postgres' ] && [ "$DB_NAME" != "$DB_USER" ]; then
    psql -v ON_ERROR_STOP=1 --username "postgres" --dbname "postgres" <<-EOSQL
      CREATE DATABASE "$DB_NAME" OWNER "$DB_USER";
EOSQL
  fi

  pg_ctl -D "$PGDATA" -m fast -w stop
fi

if [ "$1" = 'postgres' ]; then
  shift
  exec postgres -c listen_addresses='*' "$@"
fi

exec "$@"
