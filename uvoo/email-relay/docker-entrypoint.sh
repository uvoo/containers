#!/bin/bash
set -eu
sasldb2_fp="/var/spool/postfix/etc/sasldb2"
key_file=/etc/ssl/private/tls.key
crt_file=/etc/ssl/certs/tls.crt

if [ -n "${TLS_CRT-}" ] && [ -n "${TLS_KEY-}" ]; then
  echo "${TLS_CRT}" > $crt_file
  echo "${TLS_KEY}" > $key_file
else
  echo "TLS_CRT and TLS_KEY env vars not provided so generating self signed key/cert with DNS $MYHOSTNAME."
  openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout tls.key -out tls.crt -subj "/CN=$MYHOSTNAME" -addext "subjectAltName = DNS:$MYHOSTNAME"
  mv tls.crt ${crt_file} 
  mv tls.key ${key_file} 
fi

cd /etc/postfix/
# envtpl --keep-template master.cf.tpl
# disable postfix chroot port 25
# sed -i 's/^smtp      inet.*/smtp      inet  n       -       n       -       -       smtpd/g' /etc/postfix/main.cf

# notes enable submission
# sed -i 's/^smtp      inet.*/smtp      inet  n       -       y       -       -       smtpd/g' /etc/postfix/main.cf
# submission inet n       -       y       -       -       smtpd

init_users(){
  for smtp_user in ${SMTP_USERS}; do
    smtp_username=$(echo $smtp_user | cut -f1 -d@)
    smtp_domain=$(echo $smtp_user | cut -f2 -d@ | cut -f1 -d:)
    smtp_userpass=$(echo $smtp_user | cut -f2 -d:)
    set +x
    echo ${smtp_userpass} | saslpasswd2 -p -c -u $smtp_domain $smtp_username
  done
  sasldblistusers2
}

init_dkim(){

  sudo mkdir -p /etc/opendkim

  for mynetwork in ${MYNETWORKS}; do
    echo ${mynetwork} | sudo tee -a /etc/opendkim/TrustedHosts
  done
  signing_table_fp="/etc/opendkim/SigningTable"
  key_table_fp="/etc/opendkim/KeyTable"
  for dkim_domain in ${DKIM_DOMAINS}; do
    sudo mkdir -p /etc/opendkim/keys/${dkim_domain}
    for dkim_selector in ${DKIM_SELECTORS}; do
      line="*@${dkim_domain} $dkim_selector._domainkey.${dkim_domain}"
      if ! grep -Fxq "${line}" ${signing_table_fp}; then
        echo "Adding to SigningTable: ${line}"
        echo "${line}" | sudo tee -a ${signing_table_fp}
      fi
      line="${dkim_selector}._domainkey.${dkim_domain} ${dkim_domain}:${dkim_selector}:/etc/opendkim/keys/${dkim_domain}/${dkim_selector}.private"
      if ! grep -Fxq "${line}" ${key_table_fp}; then
        echo "Adding to KeyTable: ${line}"
        echo "${line}" | sudo tee -a ${key_table_fp} 
      fi
      fp="/etc/opendkim/keys/${dkim_domain}/${dkim_selector}.private"
      if ! [ -f "${fp}" ]; then
        echo "Creating missing key ${dkim_selector}._domainkey.${dkim_domain}"
        opendkim-genkey -D /etc/opendkim/keys/${dkim_domain} -s $dkim_selector -d ${dkim_domain} 
      fi
      # sudo opendkim-testkey -d ${dkim_domain} -s ${dkim_selector} -vvv
    done
  done


  sudo chmod 770 /etc/opendkim/keys
  sudo chmod 770 /etc/opendkim/keys
  sudo chmod 400 /etc/opendkim/keys/${dkim_domain}/$dkim_selector.private
  sudo chmod 444 /etc/opendkim/keys/${dkim_domain}/$dkim_selector.txt
  sudo chown -R opendkim:opendkim /etc/opendkim
  # sudo chown -R root:opendkim /etc/opendkim/keys/ 
}
# sudo chown -R postfix:postfix /var/spool/postfix

sed -i 's/etc\/nss_mdns.config/nss_mdns.config etc\/sasldb2/g' /usr/lib/postfix/configure-instance.sh

if [ -n "${RELAYHOST-}" ]; then
  postconf -e "relayhost = ${RELAYHOST}"
fi

if [ -n "${RELAY_USERNAME-}" ] && [ -n ${RELAY_PASSWORD-} ]; then
  postconf -e "smtp_sasl_password_maps = static:${RELAY_USERNAME}:${RELAY_PASSWORD}"
fi
# smtp_sasl_password_maps = static:YOUR-SMTP-USER-NAME-HERE:YOUR-SMTP-SERVER-PASSWORD-HERE

if [ -n "${HEADER_SIZE_LIMIT-}" ]; then
  postconf -e "header_size_limit = ${HEADER_SIZE_LIMIT}"
else
  postconf -e "header_size_limit = 5242880" #% 5MB 
fi

if [ -n "${SMTPD_TLS_LOGLEVEL-}" ]; then
  postconf -e "smtpd_tls_loglevel = ${SMTPD_TLS_LOGLEVEL}"
else
  postconf -e "smtpd_tls_loglevel = 0"
fi
# postconf -e 'smtpd_tls_loglevel = 1'

if [ -n "${SMTPD_TLS_SECURITY_LEVEL-}" ]; then
  postconf -e "smtpd_tls_security_level = ${SMTPD_TLS_SECURITY_LEVEL}" 
else
  # Allows the Postfix SMTP server announces STARTTLS support to remote SMTP clients,
  # but does not require that clients use TLS encryption.
  postconf -e "smtpd_tls_security_level = may" 
fi

if ! [ -n "${SMTP_TLS_SECURITY_LEVEL-}" ]; then
  # Requires tls encryption with outbound emails across the internet
  postconf -e "smtp_tls_security_level = encrypt" 
else
  postconf -e "smtp_tls_security_level = ${SMTP_TLS_SECURITY_LEVEL}" 
fi

postconf -e 'smtpd_sasl_local_domain = $myhostname'
postconf -e 'smtpd_sasl_auth_enable = yes'
postconf -e 'smtpd_sasl_security_options = noanonymous'
# mynetworks = "127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 172.16.0.0/12 10.0.0.0/8 192.168.0.0/16"
postconf -e "mynetworks = \"${MYNETWORKS}\""
postconf -e 'smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination'
# smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination
postconf -e "myhostname = ${MYHOSTNAME}"
postconf -e 'smtpd_tls_cert_file=/etc/ssl/certs/tls.crt'
postconf -e 'smtpd_tls_key_file=/etc/ssl/private/tls.key'

# DKIM Milters
postconf -e 'smtpd_milters = inet:localhost:8891'
postconf -e 'non_smtpd_milters = $smtpd_milters'
postconf -e 'milter_default_action = accept'
# postconf -e 'smtpd_milters = /run/opendkim/opendkim.sock'
# postconf -e 'smtpd_milters = inet:127.0.0.1:8891'
# postconf -e 'esmtp_destination_concurrency_limit = 20'
# postconf -e 'smtp_extra_recipient_limit = 20'
# postconf -e 'smtpd_sasl_security_options = noanonymous'
# $HOSTNAME

# Spam prevention
# postconf -e 'smtpd_client_restrictions = sleep 5'
# postconf -e 'smtpd_delay_reject = no'

postconf -e 'broken_sasl_auth_clients = yes'
    # Do not report the SASL authenticated user name in the smtpd Received message header.
    postconf -e 'smtpd_sasl_authenticated_header = no'
postconf -e 'smtpd_tls_auth_only = yes'

  # With this, the Postfix SMTP server announces STARTTLS support to remote SMTP
  # clients, but does not require that clients use TLS encryption.
  postconf -e 'smtpd_use_tls = yes'

# postconf -e 'maillog_file = /dev/stdout'

# SENDER_DOMAINS="a.com b.com"
if [ ! -z ${SENDER_DOMAINS+x} ]; then
  for i in ${SENDER_DOMAINS}; do
    echo "$i OK" >> /etc/postfix/sender_domains
    postmap /etc/postfix/sender_domains
    postconf -e "smtpd_sender_restrictions = check_sender_access hash:/etc/postfix/sender_domains, reject"
  done
fi
if [ ! -z ${RECIPIENT_DOMAINS+x} ]; then
  for i in ${RECIPIENT_DOMAINS}; do
    echo "$i OK" >> /etc/postfix/recipient_domains
    postmap /etc/postfix/recipient_domains
    postconf -e "smtpd_recipient_restrictions = check_recipient_access hash:/etc/postfix/recipient_domains, reject_unauth_destination"
  done
fi

chroot_mods(){
  sudo mkdir -p /var/spool/postfix/etc
  sudo cp /etc/resolv.conf /var/spool/postfix/etc/resolv.conf
  sudo cp /etc/sasldb2 $sasldb2_fp
  # sudo chown postfix /etc/sasldb2 # if not chroot
  sudo chown root:postfix -R /var/spool/postfix/etc
  chown root:root /var/spool/postfix
  chmod 0755 /var/spool/postfix
}
init_users
chroot_mods
init_dkim

# Startup
# /usr/sbin/opendkim -D -l -f -x /etc/opendkim.conf >> /var/log/opendkim.log 2>&1
# postfix start-fg

if [ ! -e "/var/log/mail/maillog" ]; then
  mkdir -p /var/log/mail
  echo '' > /var/log/mail/maillog
fi

exec supervisord -c /etc/supervisord.conf
