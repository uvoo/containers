#!/bin/bash
set -eu
. ../includes/main.sh

envsubst '${CLUSTER_NAME} ${LOKI_ORGID} ${LOKI_URL} ${LOKI_USER} ${LOKI_PASS} ${MIMIR_ORGID} ${MIMIR_URL} ${MIMIR_USER} ${MIMIR_PASS} ${MIMIR_ORGID}' < aks.alloy.override.values.yaml.envsubst > aks.alloy.override.values.yaml
export HELM_DIFF_IGNORE_UNKNOWN_FLAGS=true
# helm_upgrade "--install k8s-monitoring grafana/k8s-monitoring \
#   -f aks.alloy.override.values.yaml --atomic --wait"
helm_upgrade "--install k8s-monitoring grafana/k8s-monitoring \
  -f aks.alloy.override.values.yaml"

enable_node_exporter(){
  # clusterMetrics:
  #   node-exporter:
  #     deploy: true
  # Patch right after helm upgrade/install:
        # --namespace monitoring \
  kubectl patch daemonset k8s-monitoring-node-exporter \
        --type='json' -p='[
          {"op":"add","path":"/spec/template/spec/containers/0/securityContext/allowPrivilegeEscalation","value":false},
          {"op":"add","path":"/spec/template/spec/containers/0/securityContext/privileged","value":false},
          {"op":"add","path":"/spec/template/spec/containers/0/securityContext/capabilities","value":{"drop":["ALL"]}}
        ]'
  # kubectl label namespace monitoring admission.gatekeeper.sh/ignore=true --overwrite
}
# enable_node_exporter_perms
