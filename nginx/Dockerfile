FROM bitnami/nginx:1.21.1 AS builder

# start custom

USER root

ARG NGINX_VERSION=1.21.1

RUN set -x \
    && addgroup --gid 101 --system nginx \
    && adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx

RUN cat /etc/apt/sources.list

RUN set -x && \
    apt-get update && \
    apt-get install -y \
    gcc \
    libc-dev \
    make \
    libssl-dev \
    libpcre3-dev \
    # zlib1g-dev \
    # linux-headers \
    libxslt-dev \
    libgd-dev \
    libgeoip-dev \
    libperl-dev \
    libedit-dev \
    curl \
    git

WORKDIR /build

RUN curl -OL http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar -xvzf nginx-${NGINX_VERSION}.tar.gz && rm nginx-${NGINX_VERSION}.tar.gz \
    && git clone https://github.com/gabihodoroaga/nginx-ntlm-module.git

RUN cd nginx-${NGINX_VERSION}/ \
    && ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --with-perl_modules_path=/usr/lib/perl5/vendor_perl \
        --user=nginx \
        --group=nginx \
        --with-compat \
        --with-file-aio \
        --with-threads \
        --with-http_addition_module \
        --with-http_auth_request_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_mp4_module \
        --with-http_random_index_module \
        --with-http_realip_module \
        --with-http_secure_link_module \
        --with-http_slice_module \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_v2_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-stream \
        --with-stream_realip_module \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-cc-opt='-Os -fomit-frame-pointer' \
        --with-ld-opt=-Wl,--as-needed \
        # add the ntlm module
        --add-dynamic-module=../nginx-ntlm-module \
    && make modules

FROM bitnami/nginx:1.21.1

COPY --from=builder /build/nginx-${NGINX_VERSION}/objs/ngx_http_upstream_ntlm_module.so /etc/nginx/modules/ngx_http_upstream_ntlm_module.so
# end custom

EXPOSE 8080 8443

WORKDIR /app
USER 1001
ENTRYPOINT [ "/opt/bitnami/scripts/nginx/entrypoint.sh" ]
CMD [ "/opt/bitnami/scripts/nginx/run.sh" ]
