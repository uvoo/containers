docker stop postfix || true
docker rm postfix || true
mkdir -p data 
cd data
mkdir -p keys logs spool_postfix
sudo chmod 0755 keys logs spool_postfix
cd ../
sudo docker run -p 9587:8587 \
  -e SMTP_USERS="internal@localhost:PleaseChangeMe" \
  -e MYNETWORKS="127.0.0.0/8 172.16.0.0/12 10.210.77.1/32" \
  -e SENDER_DOMAINS="example.com" \
  -e RECIPIENT_DOMAINS="example.com example.org" \
  -e DKIM_DOMAINS="example.com" \
  -e DKIM_SELECTORS="internalrelay" \
  -e MYHOSTNAME="internalrelay.example.com" \
  -e SMTP_TLS_SECURITY_LEVEL="may" \
  -e DEFAULT_DESTINATION_RATE_DELAY="1s" \
  -e INITIAL_DESTINATION_CONCURRENCY=3 \
  -v ${PWD}/data/keys:/etc/opendkim/keys \
  -v ${PWD}/data/logs:/var/log/mail\
  -v ${PWD}/data/spool_postfix:/var/spool/postfix \
  --hostname internalrelay.example.com \
  --name postfix -d postfix

  # --dns=10.x.x.y \
  # -e POLICY_SERVICE=127.0.0.1:10023 \
  # -e TLS_KEY="-----BEGIN PRIVATE KEY-----
# -----END PRIVATE KEY-----" \
#   -e TLS_CRT="-----BEGIN CERTIFICATE-----
# -----END CERTIFICATE-----" \

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