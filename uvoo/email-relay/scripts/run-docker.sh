sudo docker stop postfix || true
sleep 5
sudo docker rm postfix || true
mkdir -p data
cd data
mkdir -p keys logs spool_postfix
sudo chmod 0755 keys logs spool_postfix
cd ../
sudo docker run -p 587:8587 -p 25:8587 \
  --dns=8.8.8.8 \
  -e SMTP_USERS="internal@localhost:ChangeMePlease-alskdfj" \
  -e MYNETWORKS="127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 172.16.0.0/12 10.0.0.0/8 192.168.0.0/16 192.168.227.227/32" \
  -e SENDER_DOMAINS="example.com" \
  -e RECIPIENT_DOMAINS="example.com example.org" \
  -e DKIM_DOMAINS="example.com" \
  -e DKIM_SELECTORS="internalrelay" \
  -e MYHOSTNAME="internalrelay.example.com" \
  -e SMTP_TLS_SECURITY_LEVEL="may" \
  -e DEFAULT_DESTINATION_RATE_DELAY="0s" \
  -e INITIAL_DESTINATION_CONCURRENCY=3 \
  -e DEFAULT_DESTINATION_CONCURRENCY_LIMIT=3 \
  -e TLS_KEY="-----BEGIN PRIVATE KEY-----
-----END PRIVATE KEY-----" \
  -e TLS_CRT="-----BEGIN CERTIFICATE-----
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
-----END CERTIFICATE-----" \
  -v ${PWD}/data/keys:/etc/opendkim/keys \
  -v ${PWD}/data/logs:/var/log/mail\
  -v ${PWD}/data/spool_postfix:/var/spool/postfix \
  --hostname internalrelay.example.com \
  --name postfix -d postfix \
  --restart always
