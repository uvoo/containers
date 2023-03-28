docker rm postfix -f || true
  # -v ${PWD}/etc/postfix:/etc/postfix \
  # -v ${PWD}/etc/mailname:/etc/mailname \
  # -v ${PWD}/etc/postfix:/etc/postfix \
  # -e MYNETWORKS="127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 172.16.0.0/12 10.0.0.0/8 192.168.0.0/16" \
  # -e MYNETWORKS="192.168.0.0/16" \
  # -e MYNETWORKS="172.16.0.0/12" \
  # -e MYNETWORKS="10.210.77.1/32" \
  # -e MYNETWORKS="127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 10.0.0.0/8" \
  # -e MYNETWORKS="127.0.0.0/8 172.16.0.0/12 10.0.0.0/8" \
  # -e MYDOMAINS_MY="uvoo.me:mail" \
  # -e FQDN=mail.uvoo.me \
  # -v ${PWD}/spool_postfix:/var/spool/postfix\
mkdir -p data 
cd data
mkdir -p keys logs spool_postfix
sudo chmod 0777 keys logs spool_postfix
cd ../
# sudo chmod 0777 data
  ## -v ${PWD}/data/spool:/var/spool \
  # -e maildomain=mail.uvoo.me -e smtp_user=user:pwd \
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
  # -v ${PWD}/spool:/var/spool \
  # -v ${PWD}/keys:/etc/opendkim/keys \
  # -v ${PWD}/logs:/var/log/mail\

# /etc/ssl/certs
# /etc/ssl/private
