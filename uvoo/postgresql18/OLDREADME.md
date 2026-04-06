# Readme

PGPASSWORD=supersecret psql -h localhost -p 35432 -U app -d app

## Test build 

### Build

```
mkdir -p secrets
openssl rand -base64 32 | tr -d '\n' > secrets/postgres_password.txt
chmod 600 secrets/postgres_password.txt
```

```
docker build -t pg-trixie .
```


### Run

Since this custom standalone build drops the official Docker entrypoint scripts, the initdb process, pg_hba.conf configuration, and listen_addresses binding must be handled manually when launching an empty data directory.

```
docker run --rm -it \
  --name pg-test \
  -p 5432:5432 \
  pg-trixie \
  bash -c "initdb -D \$PGDATA && echo 'host all all all trust' >> \$PGDATA/pg_hba.conf && postgres -c listen_addresses='*'"
```

### Connect

```
psql -h localhost -U postgres -d postgres
```


