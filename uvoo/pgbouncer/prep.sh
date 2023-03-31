#!/bin/sh
set -e

apk add -U --no-cache --upgrade busybox
apk add -U --no-cache autoconf autoconf-doc automake udns udns-dev curl gcc libc-dev libevent libevent-dev libtool make openssl-dev pkgconfig postgresql-client
curl -o  /tmp/pgbouncer-$VERSION.tar.gz -L https://pgbouncer.github.io/downloads/files/$VERSION/pgbouncer-$VERSION.tar.gz
cd /tmp
tar xvfz /tmp/pgbouncer-$VERSION.tar.gz
cd pgbouncer-$VERSION
pwd
ls -lhat
./configure --prefix=/usr --with-udns
make
cp pgbouncer /usr/bin
mkdir -p /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer
cp etc/pgbouncer.ini /etc/pgbouncer/pgbouncer.ini.example
cp etc/userlist.txt /etc/pgbouncer/userlist.txt.example
touch /etc/pgbouncer/userlist.txt
# addgroup -g 101 -S postgres
# adduser -u 101 -S -D -H -h /var/lib/postgresql -g "Postgres user" -s /bin/sh -G postgres postgres
chown -R postgres /var/run/pgbouncer /etc/pgbouncer
cd /tmp
rm -rf /tmp/pgbouncer*
apk del --purge autoconf autoconf-doc automake udns-dev curl gcc libc-dev libevent-dev libtool make libressl-dev pkgconfig
