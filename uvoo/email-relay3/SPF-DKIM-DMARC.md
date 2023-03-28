# DNS Records for Outbound Mail 

Here are some examples of DNS records for SPF, DKIM & DMARC

# SPF
Type: TXT
Name: @
Data: v=spf1 ip4:1.x.x.x ip4:1.x.x.y -all

# DKIM
Type: TXT
Name: mail._domainkey
Data: k=rsa; t=s; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDTxX66RR700Lqc9+byVh5TA9jzPFXP+cyx7S3lGUkWCnEIYXd4hm1EFjfhOcyKpNmDb7Z/9bX7gJ1+p8vedq/MkOZ2saHpq1hnh83P4kmVmQzlYIEgHdDfVb6jgq3Y7j8LynXsRHLZribidIXUVdEO+QsrrlYd/TkgchB/5eyZcwIDAQAB

# DMARC
Type: TXT
Name: _dmarc
Data: v=DMARC1;p=none;sp=reject;pct=100;rua=mailto:dmarcreports@uvoo.me;

## Notes
none, quarantine, reject

