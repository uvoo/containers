#!/bin/bash
set -eu
. ../includes/main.sh

required_vars=(
  LOKI_AZURE_ACCOUNT_NAME
  LOKI_AZURE_ACCOUNT_KEY
  LOKI_CHUNKS_CONTAINER_NAME
  LOKI_RULER_CONTAINER_NAME
  LOKI_ADMIN_CONTAINER_NAME
  LOKI_REPLICAS
  LOKI_MAX_UNAVAILABLE_REPLICAS
  LOKI_GATEWAY_INGRESS_HOST
  LOKI_SAMPLES_MAX_AGE
  LOKI_MAX_UNAVAILABLE_REPLICAS
  LOKI_INGESTER_PVC_SIZE
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Error: Environment variable $var is missing."
    exit 1
  fi
done
echo Proceding in 5 seconds; sleep 5

basic_auth() {
  local secret=loki-basic-auth
  local tmp
  # 1) deterministic htpasswd
  tmp=$(mktemp)
  HASH=$(openssl passwd -apr1 -salt 'Az' "${LOKI_PASS}")
  printf '%s:%s\n' "${LOKI_USER}" "${HASH}" > "$tmp"

  # 2) only create or update if content really changed
  if ! kubectl get secret "$secret" >/dev/null 2>&1; then
    echo "Creating $secret…"
    kubectl create secret generic "$secret" --from-file=".htpasswd"="$tmp"
  else
    existing=$(kubectl get secret "$secret" -o json \
      | jq -r '.data[".htpasswd"]' | base64 -d)
    if [ "$existing" != "$(cat "$tmp")" ]; then
      echo "Updating $secret…"
      kubectl create secret generic "$secret" --from-file=".htpasswd"="$tmp" \
        --dry-run=client -o yaml | kubectl apply -f -
    else
      echo "$secret is up-to-date."
    fi
  fi

  rm -f "$tmp"

  # Check and create/update the canary-basic-auth secret
  existing_user=$(kubectl get secret canary-basic-auth -o jsonpath='{.data.username}' 2>/dev/null | base64 -d || echo "")
  existing_pass=$(kubectl get secret canary-basic-auth -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "")

  if [[ "$existing_user" != "$LOKI_USER" || "$existing_pass" != "$LOKI_PASS" ]]; then
    echo "Creating or updating canary-basic-auth secret..."
    kubectl create secret generic canary-basic-auth \
      --from-literal=username=$LOKI_USER \
      --from-literal=password=$LOKI_PASS \
      --dry-run=client -o yaml | kubectl apply -f -
  else
    echo "canary-basic-auth secret is up-to-date."
  fi
}

basic_auth

envsubst '${LOKI_INGESTER_PVC_SIZE} ${LOKI_SAMPLES_MAX_AGE} ${LOKI_CHUNKS_CONTAINER_NAME} ${LOKI_RULER_CONTAINER_NAME} ${LOKI_ADMIN_CONTAINER_NAME} ${LOKI_AZURE_ACCOUNT_NAME} ${LOKI_AZURE_ACCOUNT_KEY} ${LOKI_REPLICAS} ${LOKI_MAX_UNAVAILABLE_REPLICAS} ${LOKI_GATEWAY_INGRESS_HOST}' < override.values.yaml.envsubst > override.values.yaml
export HELM_DIFF_IGNORE_UNKNOWN_FLAGS=true
helm_upgrade "--install loki grafana/loki -f override.values.yaml --atomic --wait"
# These will break stuff & not work as expected helm_upgrade "--install loki grafana/loki --set loki.structuredConfig.server.max_request_body_size=52428800 --set gateway.nginxConfig.clientMaxBodySize=40M -f override.values.yaml"
