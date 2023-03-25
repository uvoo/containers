# FROM ubuntu:lunar
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
    dovecot-core \
    dovecot-pop3d \
    dovecot-imapd \
    iputils-ping
    # dovecot-core \
    # dovecot-pop3d \
    # dovecot-imapd \

# RUN apt-get update && apt-get install -y postfix openssl dnsutils python3-pip iproute2 iputils-ping
# RUN python3 -m pip install --break-system-packages envtpl
RUN python3 -m pip install envtpl
# RUN python3 -m pip cache remove *
# RUN apt-get clean
WORKDIR /app
# COPY main.cf /etc/postifx/main.cf
# COPY master.cf /etc/postifx/master.cf
# ADD poo.cf /etc/postifx/poo.cf
# ADD ./poo.cf /tmp/
# ADD ./poo.cf /etc/postifx/poo.cf
# ADD master.cf /etc/postifx/master.cf
# COPY ./main.cf.tpl /app/postfix/
# COPY ./master.cf.tpl /app/postfix/
COPY ./main.cf.tpl /etc/postfix/
COPY ./master.cf.tpl /etc/postfix/
COPY ./10-auth.conf.tpl /etc/dovecot/conf.d/
COPY ./10-master.conf.tpl /etc/dovecot/conf.d/
# COPY ./scripts/tests.sh . 
# RUN chmod +x tests.sh
# COPY main.cf /app/
# COPY master.cf /app/
# SHELL ["/bin/bash", "-c"]

# USER root
EXPOSE 25
#ENTRYPOINT ["/run.sh"]
# CMD ["/run.sh"]
# CMD ["/run.sh"]
# /usr/lib/postfix/sbin/master -w
# CMD ["postfix", "start-fg"]
# CMD ["/usr/libexec/postfix/master","-c", "/etc/postfix", "-d"]
# CMD ["/usr/lib/postfix/sbin/master","-c", "/etc/postfix", "-d"]
# CMD ["postfix", "start-fg"]
# RUN cp /tmp/main.cf /etc/postfix/
# RUN cp /tmp/master.cf /etc/postfix/
# CMD ["postfix", "-c", "/etc/postfix" , "start-fg"]
# CMD ["postfix", "start-fg"]
# CMD [ cp /etc/resolv.conf /var/spool/postfix/etc/resolv.conf, "postfix", "start-fg"]
# RUN openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout tls.key -out tls.crt -subj \"/CN=$FQDN\" -addext \"subjectAltName = DNS:$FQDN\""
# RUN mv tls.crt /etc/ssl/certs/ 
# RUN mv tls.key /etc/ssl/private/ 
# CMD cp /etc/resolv.conf /var/spool/postfix/etc/resolv.conf && postfix start-fg

COPY ./docker-entrypoint.sh /app/ 
USER root
STOPSIGNAL SIGUSR1
ENTRYPOINT ["/app/docker-entrypoint.sh"]
# ENTRYPOINT ["/bin/bash", "-c", "/docker-entrypoint.sh"]
# CMD ["postgres"]
# CMD ["/app/tests.sh 2>&1"]
# CMD ["echo foothis 2>&1"]
# CMD ["postconf -d mail_version"]
 # CMD ["/usr/lib/postfix/sbin/master","-c", "/etc/postfix", "-d"]
# fqdn=%s; openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout tls.key -out tls.crt -subj \"/CN=$fqdn\" -addext \"subjectAltName = DNS:$fqdn\""
# run postconf -e myhostname=mail.example.com
# run postconf -e mydestination="mail.example.com, example.com, localhost.localdomain, localhost"
# run postconf -e mail_spool_directory="/var/spool/mail/"
# run postconf -e mailbox_command=""
