# Getting Started with Docker

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
