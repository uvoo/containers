docker rm postfix -f || true
  # -v ${PWD}/etc/postfix:/etc/postfix \
  # -v ${PWD}/etc/mailname:/etc/mailname \
  # -v ${PWD}/etc/postfix:/etc/postfix \
docker run -p 8025:25 \
  -e maildomain=mail.uvoo.me -e smtp_user=user:pwd \
  -e FQDN=mail.uvoo.me \
  -e USERPASS=foo \
  --hostname mail.uvoo.me \
  --name postfix -d postfix

# /etc/ssl/certs
# /etc/ssl/private
