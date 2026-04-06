# Readme

```
docker build -t uvoo/postgresql:18.3-trixie-0 .
```

```
docker-compose down -v 
docker-compose up
PGPASSWORD=supersecret psql -h localhost -p 35432 -U app -d app
```



