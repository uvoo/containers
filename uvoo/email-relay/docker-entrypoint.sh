#!/bin/bash
set -eux

key_file=/etc/ssl/private/tls.key
crt_file=/etc/ssl/certs/tls.crt
if ! [ -f "${key_file}" ]; then
  openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout tls.key -out tls.crt -subj "/CN=$FQDN" -addext "subjectAltName = DNS:$FQDN"
  mv tls.crt ${crt_file} 
  mv tls.key ${key_file} 
fi

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


  sudo chmod 400 /etc/opendkim/keys/${dkim_domain}/$dkim_selector.private
  sudo chmod 444 /etc/opendkim/keys/${dkim_domain}/$dkim_selector.txt
  sudo chown -R opendkim:opendkim /etc/opendkim
  # sudo chown -R root:opendkim /etc/opendkim/keys/ 
}

cp /etc/resolv.conf /var/spool/postfix/etc/resolv.conf

sed -i 's/etc\/nss_mdns.config/nss_mdns.config etc\/sasldb2/g' /usr/lib/postfix/configure-instance.sh

postconf -e 'smtpd_sasl_local_domain = $myhostname'
postconf -e 'smtpd_sasl_auth_enable = yes'
postconf -e 'smtpd_sasl_security_options = noanonymous'
postconf -e 'smtpd_tls_loglevel = 1'
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

  # With this, the Postfix SMTP server announces STARTTLS support to remote SMTP clients,
  # but does not require that clients use TLS encryption.
  postconf -e 'smtpd_tls_security_level = may'
  postconf -e 'smtp_tls_security_level = may'
# postconf -e 'maillog_file = /dev/stdout'

chown root:postfix /etc/sasldb2
ln /etc/sasldb2 /var/spool/postfix/etc/

set +x
echo ${USERPASS} | saslpasswd2 -p -c -u localhost test
sasldblistusers2

init_dkim
# /usr/sbin/opendkim -f 
# /usr/sbin/opendkim >> /var/log/opendkim.log 2>&1 
# opendkim -D -l -f -x /etc/opendkim.conf
# opendkim -D -l -x /etc/opendkim.conf

# postfix start-fg

    if [ ! -e "/var/log/mail/maillog" ]; then
      mkdir /var/log/mail
      echo '' > /var/log/mail/maillog
    fi

    ## Launch
    exec supervisord -c /etc/supervisord.conf
