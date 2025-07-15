# Pushproxy for promtheus push gateway & mimir

Proxy is http json raw on front and then protobuf on backend

This proxy authenticates user and then adds X-Scope-OrgID value to header for multi-tenancy in mimir. It adds org_id label in mimir.

X-Scope-OrgID: org1

## k8s-deploy-example

kubectl apply -f pushproxy-auth-users.secret.yaml -f pushproxy-env.secret.yaml -f pushproxy.deploy.yaml

./client-push.sh

Grafana set basic auth and correct header X-Scope-OrgID, i.e. "X-Scope-OrgID: org1"

Open Datasource and do metrics browser promql query like: {org_id="org1"}
