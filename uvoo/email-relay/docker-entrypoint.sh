#!/bin/bash
set -eu

key_file=/etc/ssl/private/tls.key
crt_file=/etc/ssl/certs/tls.crt
if ! [ -f "${key_file}" ]; then
  openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout tls.key -out tls.crt -subj "/CN=$FQDN" -addext "subjectAltName = DNS:$FQDN"
  mv tls.crt ${crt_file} 
  mv tls.key ${key_file} 
fi

cd /etc/postfix/
envtpl --keep-template master.cf.tpl
envtpl --keep-template main.cf.tpl

cd /etc/dovecot/conf.d/
envtpl --keep-template 10-auth.conf.tpl
envtpl --keep-template 10-master.conf.tpl

cp /etc/resolv.conf /var/spool/postfix/etc/resolv.conf

sed -i 's/etc\/nss_mdns.config/nss_mdns.config etc\/sasldb2/g' /usr/lib/postfix/configure-instance.sh

postconf -e 'cyrus_sasl_config_path = /etc/postfix/sasl'
postconf -e 'smtpd_sasl_local_domain = $myhostname'
postconf -e 'smtpd_sasl_auth_enable = yes'
postconf -e 'smtpd_sasl_security_options = noanonymous'
postconf -e 'smtpd_tls_loglevel = 1'

chown postfix /etc/sasldb2
ln /etc/sasldb2 /var/spool/postfix/etc/

echo "pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: CRAM-MD5 DIGEST-MD5 LOGIN PLAIN" > /etc/postfix/sasl/smtpd.conf

set +x
echo ${USERPASS} | saslpasswd2 -p -c -u localhost test
sasldblistusers2

postfix start-fg
