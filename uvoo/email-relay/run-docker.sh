docker rm postfix -f || true
mkdir -p data 
cd data
mkdir -p keys logs spool_postfix
sudo chmod 0777 keys logs spool_postfix
cd ../
docker run -p 8025:25 \
  -e SMTP_USERNAME=tester@localhost \
  -e SMTP_USERPASS=PleaseChangeMe \
  -e MYNETWORKS="127.0.0.0/8 172.16.0.0/12 10.210.77.1/32" \
  -e DKIM_DOMAINS="uvoo.me" \
  -e DKIM_SELECTORS="default mail" \
  -e MYHOSTNAME="mail.uvoo.me" \
  -v ${PWD}/data/keys:/etc/opendkim/keys \
  -v ${PWD}/data/logs:/var/log/mail\
  -v ${PWD}/data/spool_postfix:/var/spool/postfix \
  --hostname mail.uvoo.me \
  --name postfix -d postfix

# Notes
# -e MYNETWORKS="127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 172.16.0.0/12 10.0.0.0/8 192.168.0.0/16" \
# /etc/ssl/certs
# /etc/ssl/private
