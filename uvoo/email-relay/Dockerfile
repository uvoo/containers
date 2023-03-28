FROM ubuntu:jammy
RUN set -eux && \
    apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
    postfix \
    sudo \
    opendkim \
    opendkim-tools \
    nano \
    vim \
    openssl \
    dnsutils \
    python3-pip \
    iproute2 \
    libsasl2-modules \
    supervisor \
    rsyslog \
    ca-certificates \
    sasl2-bin \
    iputils-ping

# RUN python3 -m pip install --break-system-packages envtpl
RUN python3 -m pip --no-cache-dir install envtpl
# RUN python3 -m pip cache remove *
RUN apt-get clean
WORKDIR /app
# COPY ./main.cf.tpl /etc/postfix/
# COPY ./master.cf.tpl /etc/postfix/
COPY ./opendkim.conf /etc/
COPY ./supervisord.conf /etc/supervisord.conf
COPY ./rsyslog.conf /etc/rsyslog.conf

EXPOSE 25

COPY ./docker-entrypoint.sh /app/ 
USER root
STOPSIGNAL SIGUSR1
ENTRYPOINT ["/app/docker-entrypoint.sh"]
