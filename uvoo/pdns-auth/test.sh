pdnsutil create-zone uvoo.com
pdnsutil add-record uvoo.com www A 192.168.1.23
dig +short  www.uvoo.com -p 53 @127.0.0.1

pdnsutil check-all-zones
pdnsutil rectify-all-zones
