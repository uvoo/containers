# Simple HTTP/HTTPS echo server via Go

This is a echo http/https server for back-end testing.

The tls crt & key pem files are created if it doesn't exist in container.

listeners are on 8080 (http) and 8443 (https)

```
docker pull uvoo/go-https-echo
docker run -p 8443:8443 -p 8080:8080 uvoo/go-https-echo
```

```
$ curl -k https://localhost:8443/foo
```
```
GET /foo HTTP/1.1
Host: localhost:8443
User-Agent: curl/7.68.0
Accept: */*
```

```
$ curl -k http://localhost:8080/bar
```
```
GET /bar HTTP/1.1
Host: localhost:8080
User-Agent: curl/7.68.0
Accept: */*
```

# ToDo

- [ ] Allow passing tls cert/key in via env vars.
- [ ] Allow pass FQDN for auto created tls cert via env var. 
