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
docker run -p 8025:25 \
  -e maildomain=mail.uvoo.me -e smtp_user=user:pwd \
  -e FQDN=mail.uvoo.me \
  -e USERPASS=foo \
  -e MYNETWORKS="127.0.0.0/8 172.16.0.0/12 10.210.77.1/32" \
  -e DKIM_DOMAINS="uvoo.me" \
  -e DKIM_SELECTORS="default mail" \
  -e MYHOSTNAME="mail.uvoo.me" \
  -v ${PWD}/opendkim:/etc/opendkim \
  --hostname mail.uvoo.me \
  --name postfix -d postfix

# /etc/ssl/certs
# /etc/ssl/private
