#!/bin/bash
set -eu

if [[ -z "$@" ]]; then
  echo "Usage: $0 <branch-name>"
  echo "Usage: $0 dev"
  exit 1
fi
branch=$1
cnf_file=info


container_build_push(){
  NAMESPACE=kaniko
  kubectl config set-context --current --namespace=$NAMESPACE

  kubectl delete --ignore-not-found=true pod build
  export REPO=$1
  export TAG=$2
  export IMAGE=$REGISTRY/$REPO
  overrides=$(cat ../../envsubst.overrides.yaml | yq -o=json | envsubst)
  # --rm --stdin=true \
  kubectl run kaniko \
  --stdin=true \
  --image=${KANIKO_EXECUTOR_SRC_IMAGE} --restart=Never \
  --overrides="${overrides}"

  kubectl logs -f build --all-containers=true
}


main(){
  if [ $branch = "dev" ]; then
    DOT_ENV_NAME=".dev"
  elif [ $branch = "main" ]; then
    DOT_ENV_NAME=""
  else
    echo "E: Unsupported branch."
    exit 1
  fi
  . "${DOT_ENV_NAME}.env"
  . "${DOT_ENV_NAME}.env.secrets"
   # ./scripts/process-templates.sh

  out=$(./scripts/az-login.sh)

  out=$(./scripts/update_kubectl_host_files.sh $RGRP_NAME $AKS_NAME)

  repos=($(find . -maxdepth 2 -mindepth 2 -type d \
    ! -path "./scripts*" ! -path "./notes*" ! -path "./.git*" \
    ! -path "./trash*" ! -path "./.github*" -printf '%P\n'))

  merge_hash1=$(git log --merges --format="%H" -n 1)
  merge_hash2=$(git log --merges --format="%H" -n 2 | tail -1)
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  echo "Running container diffs for branch $current_branch."
  echo "If changes between last merge to dev/main will update container."
  echo "Output of builds will be displayed."

  for repo in "${repos[@]}"; do
    cd "${repo}"

    unset force
    unset git_diff
    unset info_1
    unset info_2
    unset version
    unset version_1
    unset version_2
    unset version_diff
    if [ -f $cnf_file ]; then
      info_1=$(git show "${merge_hash1}:${repo}/$cnf_file" || true)
      info_2=$(git show "${merge_hash2}:${repo}/$cnf_file" || true)
      version_1=$(echo -n "${info_1}" | yq e .version)
      version_2=$(echo -n "${info_2}" | yq e .version)
      force=$(echo "${info_1}" | yq e .force)
      version_diff=$(diff <( echo "$version_2" ) <( echo "$version_1" ) || true)
      version="${version_1}"
      git_diff=$(git diff --unified=0 --color=always ${merge_hash2} ${merge_hash1} -- ./)
    fi
    set +u
    if [ ! "${version_diff}" ] && [ ! "$force" = "true" ]; then
      set -u
      cd ../../
      continue
    else
      echo "Release version changes detected in repo $repo."
      echo "Release version delta: ${version_diff}"
      echo "Git diff of $repo:"
      echo "$git_diff"
      echo "Building repo $repo version $version & pushing to container registry."
      container_build_push "${repo}" "${version}"
      cd ../../
    fi
  done
}


main
