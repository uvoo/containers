#!/bin/bash
set -eu
. ../includes/main.sh

required_vars=(
  MIMIR_USER
  MIMIR_PASS
  MIMIR_AZURE_ACCOUNT_NAME
  MIMIR_AZURE_ACCOUNT_KEY
  MIMIR_GATEWAY_INGRESS_HOST
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Error: Environment variable $var is missing."
    exit 1
  fi
done
echo Proceding in 5 seconds; sleep 5

basic_auth() {
  # htpasswd -cb ./.htpasswd $MIMIR_USER ${MIMIR_PASS}
  # kubectl create secret generic mimir-basic-auth --from-file=auth=./.htpasswd --dry-run=client --save-config -o yaml | kubectl apply -f -
  local secret=mimir-basic-auth
  local tmp
  # 1) deterministic htpasswd
  tmp=$(mktemp)
  HASH=$(openssl passwd -apr1 -salt 'Az' "${MIMIR_PASS}")
  printf '%s:%s\n' "${MIMIR_USER}" "${HASH}" > "$tmp"

  # 2) only create or update if content really changed
  if ! kubectl get secret "$secret" >/dev/null 2>&1; then
    echo "Creating $secret…"
    kubectl create secret generic "$secret" --from-file=.htpasswd="$tmp"
  else
    existing=$(kubectl get secret "$secret" -o json \
      | jq -r '.data[".htpasswd"]' | base64 -d)
    if [ "$existing" != "$(cat "$tmp")" ]; then
      echo "Updating $secret…"
      kubectl create secret generic "$secret" --from-file=.htpasswd="$tmp" \
        --dry-run=client -o yaml | kubectl apply -f -
    else
      echo "$secret is up-to-date."
    fi
  fi

  rm -f "$tmp"
}

basic_auth

envsubst '${MIMIR_USER} ${MIMIR_PASS} ${MIMIR_GATEWAY_INGRESS_HOST} ${MIMIR_AZURE_ACCOUNT_NAME} ${MIMIR_AZURE_ACCOUNT_KEY}' < override.values.yaml.envsubst > override.values.yaml
export HELM_DIFF_IGNORE_UNKNOWN_FLAGS=true
helm_upgrade "--install mimir grafana/mimir-distributed -f override.values.yaml --atomic --wait"
