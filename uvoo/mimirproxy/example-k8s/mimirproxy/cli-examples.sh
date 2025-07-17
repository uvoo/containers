curl -u $ADMIN_USERNAME:$ADMIN_PASSWORD \
  -X POST \
  -d "username=test2" \
  -d "password=secret" \
  -d "org_id=org1" \
  http://mimirproxy.mimirproxy.svc.cluster.local/admin/users


curl -u $ADMIN_USERNAME:$ADMIN_PASSWORD \
  -X POST \
  http://mimirproxy.mimirproxy.svc.cluster.local/admin/stats

  # http://mimir-proxy.mimir-proxy.svc.cluster.local/admin/users?list
  # http://mimir-proxy.mimir-proxy.svc.cluster.local/admin/refresh
