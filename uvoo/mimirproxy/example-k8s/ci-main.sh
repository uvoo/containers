#!/bin/bash
set -eu


print_header_line(){
  text=$1
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


add_repos(){
  add_helm_repo ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update
}


run_ns(){
  print_header_line "Namespace $1 "
  sleep 5
  cd namespaces/$1/
  ./main.sh
  cd ../../
}


run_namespaces(){
 region=$1
  echo "Deploying k8s namespace in $RGRP_NAME."
  run_ns ingress-nginx
  if [[ -v CI_RUN_TESTS ]]; then
    print_header_line "Running Tests"
  fi
}


main(){
  echo Running on environement $ENV_NAME in 10 seconds.; sleep 10
  if [[ "$ENV_NAME" == "dev" || "$ENV_NAME" == "prod" ]]; then
    echo "The env $ENV_NAME will update in 5 seconds"; sleep 5
  else
    echo "The $ENV_NAME is not supported in CI/CD. Check CI/CD code."
    exit 1
  fi

  [[ -v GITHUB_ACTIONS ]] && HELM_PLUGINS=/usr/local/share/helm/plugins

  terraform fmt -recursive -check -diff

  if [[ "$DEPLOY_PRIMARY_REGION" == "true" ]]; then
    ./scripts/az-login.sh
    print_header_line "Primary Region K8S Cluster"
    if az k8s show --resource-group "$RGRP_NAME" --name "$K8S_NAME" > /dev/null 2>&1; then
      ./scripts/k8s-setup-kube-config.sh
      add_repos
      run_namespaces primary
    fi
  fi

  if [[ "$DEPLOY_SECONDARY_REGION" == "true" ]]; then
    echo do secondary
  fi
}


main
