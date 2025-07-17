export NS=$(basename $(pwd))
export sleep_seconds=10
# . ../../$DOT_ENV_NAME.env
# . ../../$DOT_ENV_NAME.env.secrets


helm_cmd_sleep_seconds=10
helm_upgrade(){
  cmd=$1
  lines=$(eval "helm diff upgrade $cmd")
  if [[ $(echo -n "$lines" | wc -l) > 0 ]]; then
    # echo "$lines" | grep "^+\|^-" || true
    echo "$lines" || true
    echo "Helm changes detected."
    if [[ -v CI_APPLY ]]; then
      echo "Running helm upgrade in $helm_cmd_sleep_seconds."; sleep $helm_cmd_sleep_seconds
      eval "helm upgrade $cmd"
    # else
    #   echo "Apply is not set but here is diff."
    #   echo "$lines"
    fi
  else
    echo "Namespace ${NS} is unchanged."
  fi
}


kubectl_apply(){
  cmd=$1
  lines=$(eval "kubectl diff $cmd") || true
  if [[ $(echo -n "$lines" | wc -l) > 0 ]]; then
    echo "$lines" || true
    if [[ -v CI_APPLY ]]; then
      echo "Changes detected. Running kubectl apply in $sleep_seconds seconds."; sleep $sleep_seconds
      eval "kubectl apply $cmd"
    fi
  # else
  #   echo "Namespace ${NS} apply is unchanged."
  fi
}


create_external_secrets_if_external_secrets_yaml_exists(){
  es_file_name=external-secrets.yaml
  es_store_file_name=external-secrets-store.yaml
  if [ -f "$es_file_name" ]; then
    echo "File $es_file_name detected for NS $NS. Running vault external-secrets function."
    if [ ! -f "$es_store_file_name" ]; then
      name=$es_store_file_name; [ -L $name ] || ln -s ../../$name $name
    fi

    create_ns_vault_token

    kubectl_apply "-f external-secrets-store.yaml"
    kubectl_apply "-f external-secrets.yaml"
  fi
}

set_ns(){
  current_ns=$(kubectl config view --minify | grep namespace | awk -F':' '{ print $2 }' | tr -d " \t\n\r")
  if [ "$current_ns" != "$NS" ]; then
    kubectl config set-context --current --namespace=$NS
  fi
}

create_namespace_from_tpl(){
  if [[ "$NS" == "cnpg-system" || "$NS" == "monitoring" || "$NS" == "monitoring-system" ]]; then
    if ! kubectl get namespace $NS > /dev/null 2>&1; then
      kubectl create namespace $NS
    # kubectl create namespace $NS --dry-run=server -o yaml | kubectl apply -f -
    fi
    echo "skip ns baseline"
    return 0
  fi
  if [ -f ns.yaml ]; then
    # kubectl_apply "-f ns.yaml"
    kubectl apply -f ns.yaml
  elif [ ! -f ns.yaml.tpl ]; then
    ln -s ../includes/ns.yaml.tpl ns.yaml.tpl
  fi
  [ -f ns.yaml.tpl ] && envtpl --keep-template ns.yaml.tpl
  # kubectl_apply "-f ns.yaml"
  kubectl apply -f ns.yaml
}


create_ns_vault_token(){
kubectl_apply "-f - <<EOF
---
apiVersion: v1
stringData:
  token: ${VAULT_TOKEN}
kind: Secret
metadata:
  name: vault-token
  namespace: ${NS}
  labels:
    app: external-secrets
EOF"
}

print_header_line(){
  # printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' \#
  # printf '%*s\n' "${COLUMNS:-$(tput -T cols)}" '' | tr ' ' -
  text=$1
  # line_count=${COLUMNS:-$(tput cols)}
  line_count=80
  text_count=${#text}
  adj_line_count=$((line_count - text_count ))
  echo -n "$text"
  printf '%*s\n' "$adj_line_count" '' | tr ' ' \#
}

add_helm_repo(){
  REPO_NAME="${1}"
  REPO_URL="${2}"

  if helm repo list | grep -q "^$REPO_NAME"; then
    echo "Repository '$REPO_NAME' already exists."
  else
    echo "Adding repository '$REPO_NAME'..."
    helm repo add $REPO_NAME $REPO_URL
    echo "Repository '$REPO_NAME' added."
  fi
}


print_header_line $NS
echo Running K8S namespace $NS main.sh in 5 seconds.; sleep 5
set_ns
create_namespace_from_tpl
# create_external_secrets_if_external_secrets_yaml_exists
