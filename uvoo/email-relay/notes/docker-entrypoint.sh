#!/bin/bash
set -eux
# set -eux
# set -eo pipefail

key_file=/etc/ssl/private/tls.key
crt_file=/etc/ssl/certs/tls.crt
# if [ -f "${key_file}" ]; then
if ! [ -f "${key_file}" ]; then
  openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout tls.key -out tls.crt -subj "/CN=$FQDN" -addext "subjectAltName = DNS:$FQDN"
  mv tls.crt ${crt_file} 
  mv tls.key ${key_file} 
fi

cd /etc/postfix/
# envtpl --keep-template -o /etc/postfix/master.cf /app/master.cf.tpl
envtpl --keep-template master.cf.tpl
envtpl --keep-template main.cf.tpl

cd /etc/dovecot/conf.d/
envtpl --keep-template 10-auth.conf.tpl
envtpl --keep-template 10-master.conf.tpl

# lets
# fullchain.pem
# provkey.pem
cp /etc/resolv.conf /var/spool/postfix/etc/resolv.conf

sed -i 's/etc\/nss_mdns.config/nss_mdns.config etc\/sasldb2/g' /usr/lib/postfix/configure-instance.sh

# postconf -e 'smtp_tls_security_level = may'
# postconf -e 'smtpd_tls_security_level = may'
# postconf -e 'smtp_tls_note_starttls_offer = yes'
# postconf -e 'smtpd_tls_key_file = /etc/ssl/private/tls.key'
# postconf -e 'smtpd_tls_cert_file = /etc/ssl/certs/tls.crt'
# postconf -e 'smtpd_tls_loglevel = 1'
# postconf -e 'smtpd_tls_received_header = yes'
# postconf -e 'myhostname = mail.example.com'
# postconf -e 'smtpd_sasl_type = dovecot'

# postconf -e 'cyrus_sasl_config_path = /etc/postfix/sasl'
# postconf -e 'smtpd_sasl_local_domain = $myhostname'
# postconf -e 'smtpd_sasl_auth_enable = yes'
# postconf -e 'broken_sasl_auth_clients = yes'
# postconf -e 'smtpd_sasl_security_options = noanonymous'
# postconf -e 'smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination'


postconf -e 'cyrus_sasl_config_path = /etc/postfix/sasl'
postconf -e 'smtpd_sasl_local_domain = $myhostname'
postconf -e 'smtpd_sasl_auth_enable = yes'
postconf -e 'smtpd_sasl_security_options = noanonymous'
postconf -e 'smtpd_tls_loglevel = 1'
# postconf -e 'smtpd_tls_loglevel = 2'
# postconf -e 'smtpd_sasl_type = dovecot'
# postconf -e 'smtpd_sasl_path = private/auth'
# postconf -e 'smtpd_sasl_path = private/auth'

# saslpasswd2 -c -u mydomain.com myuser
# saslpasswd2 -c -u mydomain myuser
# saslpasswd2 -c -u domain user
chown postfix /etc/sasldb2
ln /etc/sasldb2 /var/spool/postfix/etc/
# echo foo | saslpasswd2 -c -u localhost test


echo "pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: CRAM-MD5 DIGEST-MD5 LOGIN PLAIN" > /etc/postfix/sasl/smtpd.conf


# If you are using your own Certificate Authority to sign the certificate enter:
# sudo postconf -e 'smtpd_tls_CAfile = /etc/ssl/certs/cacert.pem'

# /usr/sbin/dovecot -F
#/usr/sbin/dovecot
# postconf -a
# postconf -d
# saslfinger -s
# /usr/sbin/dovecot
/usr/sbin/dovecot
postconf -e 'smtpd_sasl_type = dovecot'
# smtpd_sasl_path = inet:dovecot:12345
# smtpd_relay_restrictions = [...], permit_sasl_authenticated, reject_unauth_destination
postconf -e 'smtpd_sasl_path = inet:dovecot:12345'
set +x
echo ${USERPASS} | saslpasswd2 -p -c -u localhost test
sasldblistusers2

postfix start-fg
