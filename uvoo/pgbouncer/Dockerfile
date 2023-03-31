FROM debian:bullseye-slim
ARG VERSION_TAG=pgbouncer_1_18_0
ARG USER=app
ENV HOME="/$USER"
WORKDIR $HOME

USER root
COPY docker-entrypoint.sh $HOME

ARG BUILD_PACKAGES="libssl-dev libudns-dev libevent-dev libc-dev python3-pip git libtool pandoc make pkg-config postgresql-client procps iproute2"
# libaudit1 libbsd0 libc-ares2 libcap-ng0 libedit2 libevent-2.1-7 libffi7 libgcc-s1 libgmp10 libgnutls30 libhogweed6 libicu67 libidn2-0 libldap-2.4-2 liblzma5 libmd0 libnettle8 libp11-kit0 libpam0g libsasl2-2 libssl1.1 libstdc++6 libtasn1-6 libtinfo6 libunistring2 libuuid1 libxml2 libxslt1.1 locales procps zlib1g
RUN apt update
RUN apt install -y $BUILD_PACKAGES

# RUN pip3 install --no-cache-dir envtpl

RUN useradd --system $USER --home /$USER
RUN chown -R $USER /$HOME

USER $USER
RUN mkdir -p /app/bin /app/cnf /app/certs
RUN cd /tmp
RUN git clone --depth 1 --branch ${VERSION_TAG} https://github.com/pgbouncer/pgbouncer.git && \
  cd pgbouncer && \
  git submodule init && \
  git submodule update && \
  ./autogen.sh && \
  ./configure --prefix=/usr/local --with-udns && \
  make && \
  mv pgbouncer /app/bin/ && \
  mv etc/pgbouncer.ini /app/cnf/pgbouncer.ini.example && \ 
  mv etc/userlist.txt /app/cnf/userlist.txt.example && \
  cd ../ 
RUN chmod -R go-rwx $HOME

USER root
RUN AUTO_ADDED_PACKAGES=$(apt-mark showauto)
RUN apt-get remove --purge -y $BUILD_PACKAGES $AUTO_ADDED_PACKAGES
RUN rm -rf /tmp/pgbouncer*

USER $USER
EXPOSE 5432
ENTRYPOINT ["/app/docker-entrypoint.sh"]
