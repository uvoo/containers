#!/bin/bash
set -eu
# dig +short @127.0.0.1 -p 8053 www.example.com.
alias adig="dig +short @127.0.0.1 -p 8053"
shopt -s expand_aliases
adig luaurl2.example.com
exit
adig luaurl1.example.com
adig luaport.example.com
adig www.example.com
adig luaurl.example.com
adig random.example.com


curl -v -H "X-API-Key: ${APIKEY}" http://127.0.0.1:8081/api/v1/servers/localhost | jq .
curl -v -H "X-API-Key: ${APIKEY}" http://127.0.0.1:8081/api/v1/servers/localhost/zones | jq .

exit

pdnsutil create-zone example.com
pdnsutil add-record example.com www A 192.168.1.23
dig +short  www.example.com -p 53 @127.0.0.1

pdnsutil check-all-zones
pdnsutil rectify-all-zones


