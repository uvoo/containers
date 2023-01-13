# Test complications

Create for testing
```
docker run -dit --name foo debian:bullseye
docker exec -it foo bash
```

Delete when done
```
docker rm foo -f
```

Let's look at nginx executable compliations
```
nginx -V
nginx version: nginx/1.21.1
built by gcc 8.3.0 (Debian 8.3.0-6)
built with OpenSSL 1.1.1d  10 Sep 2019
TLS SNI support enabled
configure arguments: --prefix=/opt/bitnami/nginx --with-http_stub_status_module --with-stream --with-http_gzip_static_module --with-mail --with-http_realip_module --with-http_v2_module --with-http_ssl_module --with-mail_ssl_module --with-http_gunzip_module --with-threads --with-http_auth_request_module --with-http_sub_module --with-http_geoip_module --with-compat --add-module=/bitnami/blacksmith-sandox/nginx-module-vts-0.1.18 --add-dynamic-module=/bitnami/blacksmith-sandox/nginx-module-geoip2-3.3.0 --add-module=/bitnami/blacksmith-sandox/nginx-module-substitutions-filter-0.20190806.0 --add-module=/bitnami/blacksmith-sandox/nginx-module-brotli-0.20201006.0
I have no name!@6dab0c2515aa:/app$
```
