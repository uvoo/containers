# Postfix Docs & HowTos
- https://en.wikipedia.org/wiki/Postfix_(software)
- https://www.cyberciti.biz/faq/how-to-configure-postfix-relayhost-smarthost-to-send-email-using-an-external-smptd/
- https://www.postfix.org/postconf.5.html

# Environment Variables

## Required Env Variables with example values
```
SMTP_USERNAME=tester@localhost \
SMTP_USERPASS=PleaseChangeMe \
SMTP_USERS="tester@localhost:PleaseChangeMe tester1@localhost:PleaseChangeMe" \
MYNETWORKS="127.0.0.0/8 172.16.0.0/12 10.210.77.1/32" \
DKIM_DOMAINS="uvoo.me" \
DKIM_SELECTORS="default foo" \
MYHOSTNAME="mail.uvoo.me" \
```

## More Optional Env Variables with defaults after equal
```
RELAY_HOST
RELAY_USERNAME
RELAY_PASSWORD

SMTPD_TLS_SECURITY_LEVEL=may
SMTP_TLS_SECURITY_LEVEL=encrypt
HEADER_SIZE_LIMIT=5242880 # 5MB
SMTPD_TLS_LOGLEVEL=0
```

# Getting Started with Docker

TCP 25 is usually incoming mail to be delivered to local mailboxes.
TCP 587 is usually submission mail to be relayed to external domains & mailboxes.

SMTP Auth must include user and password and use TLS/SSL verification and encryption

SMTP Trusted ip address will work if encrypted or non-encrypted so auth creds not being exposed.

So examples like below should work.
```
./scripts/client.py -H localhost -P 8587 -f no-reply@example.com -t someuser@example.org -u tester@localhost -p PleaseChangeMe
./scripts/client.py -H localhost -P 8587 -f no-reply@example.com -t someuser@example.org -N
./scripts/client.py -H localhost -P 8587 -f no-reply@example.com -t someuser@example.org  -N -n
```

```
./build.sh
./run.sh
./scripts/tests.sh
./scripts/nc.sh
./scripts/client.py
./scripts/logs.sh
```



# General Guides

https://ubuntu.com/server/docs/mail-postfix#:~:text=SMTP%20Authentication

https://wiki.debian.org/PostfixAndSASL

https://www.postfix.org/SASL_README.html

https://www.postfix.org/MAILLOG_README.html


# More
https://serverfault.com/questions/1003885/postfix-in-docker-host-or-domain-name-not-found-dns-and-docker

https://security.stackexchange.com/questions/71922/postfix-master-running-as-root

https://stackoverflow.com/questions/54976051/how-to-accept-self-signed-certificate-from-e-mail-server-via-smtplib-tsl

# Dovecot won't work for sasl

https://doc.dovecot.org/configuration_manual/howto/postfix_and_dovecot_sasl/

https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/security_guide/sect-security_guide-securing_postfix-configuring_postfix_to_use_sasl

# Issues
You can disable chroot jail if it gives you issues. It is mainly a pain with sasldb2 database defaults but have function chroot to work around it.

Postfix chroot jail causes /var/spool/postfix volume issues so that has been disabled in master.cf via master.cf.tpl with "n"

You can disable it it via there is sed line in docker-entrypoint.sh script
```
smtp      inet  n       -       n       -       -       smtpd
```

# Policy
```
smtpd_relay_restrictions = permit_mynetworks, reject_unauth_destination, check_policy_service inet:127.0.0.1:10023
```
# More options example


## run-docker.sh

```
# docker rm postfix -f || true
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
  -e SMTP_USERS="internal@localhost:pass1 foo:pass2" \
  -e MYNETWORKS="127.0.0.0/8 192.168.0.0/16" \
  -e SENDER_DOMAINS="example.com" \
  -e RECIPIENT_DOMAINS="example.com example.org" \
  -e DKIM_DOMAINS="example.com" \
  -e DKIM_SELECTORS="testrelay" \
  -e MYHOSTNAME="testrelay.example.com" \
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
  --hostname testrelay.example.com \
  --name postfix -d postfix \
  --restart always
```

## send-email.py

```
#!/usr/bin/python3
import smtplib
from email.mime.text import MIMEText

from_addr = f"test-noreply@example.com"
to_addr = f"toemail@example.com"
to_addr = f"toemail@example.com"
subject = "Test 1"
body = "This is a test email."
msg = MIMEText(body)
msg["Subject"] = subject
msg["From"] = from_addr
msg["To"] = to_addr

# server = smtplib.SMTP("localhost", 587)
server = smtplib.SMTP("<ip>", 25)
server.send_message(msg)
server.quit()

print("Email sent.")
```

## start-tls

```
#!/usr/bin/python3
import smtplib
from email.mime.text import MIMEText

from_addr = f"noreply@example.com"
to_addr = f"toemail@example.org"
subject = "Test 587 1"
body = "This is a test email."

msg = MIMEText(body)
msg["Subject"] = subject
msg["From"] = from_addr
msg["To"] = to_addr

server = smtplib.SMTP("<my ip>", 587)
server.starttls()
server.send_message(msg)
server.quit()

print("Email sent.")
```
