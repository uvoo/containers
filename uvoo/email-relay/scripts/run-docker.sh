docker rm postfix -f || true
mkdir -p data 
cd data
mkdir -p keys logs spool_postfix
sudo chmod 0755 keys logs spool_postfix
cd ../
docker run -p 8587:8587 \
  -e SMTP_USERNAME=tester@localhost \
  -e SMTP_USERPASS=PleaseChangeMe \
  -e SMTP_USERS="tester@localhost:PleaseChangeMe tester1@localhost:PleaseChangeMe" \
  -e MYNETWORKS="127.0.0.0/8 172.16.0.0/12 10.210.77.1/32" \
  -e DKIM_DOMAINS="example.com" \
  -e DKIM_SELECTORS="default mail" \
  -e MYHOSTNAME="mail.example.com" \
  -e SMTP_TLS_SECURITY_LEVEL="may" \
  -v ${PWD}/data/keys:/etc/opendkim/keys \
  -v ${PWD}/data/logs:/var/log/mail\
  -v ${PWD}/data/spool_postfix:/var/spool/postfix \
  --hostname mail.example.com \
  --name postfix -d postfix

# SMTP_TLS_SECURITY_LEVEL="may" none/may/encrypted default is encrypted
# Other env vars
# RELAY_HOST
# RELAY_USERNAME
# RELAY_PASSWORD

# SMTPD_TLS_SECURITY_LEVEL # may
# SMTP_TLS_SECURITY_LEVEL # encrypt
# HEADER_SIZE_LIMIT  # 5242880" # 5MB
# SMTPD_TLS_LOGLEVEL = 0

# Notes
# -e MYNETWORKS="127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 172.16.0.0/12 10.0.0.0/8 192.168.0.0/16" \
# /etc/ssl/certs
# /etc/ssl/private
