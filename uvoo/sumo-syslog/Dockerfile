FROM	ubuntu:22.04
WORKDIR /app
ENV	DEBIAN_FRONTEND=noninteractive
RUN	apt-get -y update \
	&& apt-get -y install rsyslog rsyslog-gnutls python3 python3-pip
RUN pip3 install envtpl

COPY rsyslog.conf.tpl /etc/rsyslog.conf.tpl
COPY digicert_ca.crt /etc/rsyslog.d/digicert_ca.crt
EXPOSE	8514

# CMD	["/rsyslog-bin/rsyslogd", "-n", "-f/etc/rsyslog.conf", "-M."]
# CMD	["/rsyslog-bin/rsyslogd", "-n", "-f/etc/rsyslog.conf", "-M."]
# /usr/sbin/rsyslogd -n
# CMD	["/app/rsyslogd", "-n", "-f/etc/rsyslog.conf", "-M."]
# CMD	["/usr/sbin/rsyslogd", "-n"]
# adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx
adduser -S -D -H -u 101 -h /app -s /sbin/nologin -G app -g app app
RUN chown 101:101 /etc/rsyslog.conf
RUN chown -R 101:101 /etc/rsyslog.d
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod 0777 /app/docker-entrypoint.sh
# STOPSIGNAL SIGUSR1
ENTRYPOINT ["/app/docker-entrypoint.sh"]
