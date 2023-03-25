FROM ubuntu:jammy
RUN set -eux && \
    apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
    postfix \
    openssl \
    dnsutils \
    python3-pip \
    iproute2 \
    libsasl2-modules \
    sasl2-bin \
    iputils-ping
    # dovecot-core \
    # dovecot-pop3d \
    # dovecot-imapd \

# RUN python3 -m pip install --break-system-packages envtpl
RUN python3 -m pip --no-cache-dir install envtpl
# RUN python3 -m pip cache remove *
RUN apt-get clean
WORKDIR /app
COPY ./main.cf.tpl /etc/postfix/
COPY ./master.cf.tpl /etc/postfix/
COPY ./10-auth.conf.tpl /etc/dovecot/conf.d/
COPY ./10-master.conf.tpl /etc/dovecot/conf.d/

EXPOSE 25

COPY ./docker-entrypoint.sh /app/ 
USER root
STOPSIGNAL SIGUSR1
ENTRYPOINT ["/app/docker-entrypoint.sh"]


# TRASH
# COPY ./scripts/tests.sh . 
# RUN chmod +x tests.sh
# SHELL ["/bin/bash", "-c"]
