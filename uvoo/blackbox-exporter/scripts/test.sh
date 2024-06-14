# curl "http://localhost:19115/probe?target=8.8.8.8&module=icmp"
# fqdn=uvoo.io
fqdn=example.com
curl "http://localhost:19116/probe?target=$fqdn"
curl "http://localhost:19116/probe?target=8.8.8.8"
curl "http://localhost:19116/metrics"
