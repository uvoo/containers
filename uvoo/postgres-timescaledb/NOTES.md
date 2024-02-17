postgresql.conf

shared_preload_libraries = 'timescaledb'

CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
