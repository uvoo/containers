#!/bin/bash
set -aeu

if [[ -z "$@" ]]; then
  echo "Usage: $0 <branch-name>"
  echo "Usage: $0 dev"
  exit 1
fi

branch=$1
cnf_file=info


docker_create_repo(){

  # if [[ $# -ne 2 ]]; then
  #   echo "Usage: $0 <org> <name>"
  #   echo "Usage: $0 uvoo example1"
  #   exit 1
  # fi

  repo=$1
  IFS='/' read -r -a repo_parts <<< "$REPO"

  # local ORG=$1
  # export NAME=$2
  # export REPO="$ORG/$NAME"
  export TOKEN=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'${DOCKERHUB_USERNAME}'", "password": "'${DOCKERHUB_TOKEN}'"}' https://hub.docker.com/v2/users/login/ | jq -r .token)

  o=$(curl -o /dev/null -w "%{http_code}" -sH "Authorization: JWT ${TOKEN}" "https://hub.docker.com/v2/repositories/${repo}")

  if [ ${o} -ne 200 ]; then
    echo "Creating repo $REPO in dockerhub."

    json=$(cat <<-EOF
      {
        "name": "${repo_parts[1]}",
        "is_private": false,
        "description": "${repo_parts[1]} docker container",
        "full_description": "${repo_parts[1]} docker container repo."
      }
EOF
    )
    curl -s -X POST -H "Authorization: JWT ${TOKEN}" \
      "https://hub.docker.com/v2/repositories/${repo_parts[0]}/" \
      -H 'Content-Type: application/json' \
      -d "${json}"
  fi

}

docker_build_push(){
  REPO=$1
  TAG=$2
  IMAGE=$REGISTRY/$REPO
  docker_create_repo $REPO
  # nocache="--no-cache"
  # nocache=""
  # docker build $nocache --tag $REPO:latest --tag $REPO:$RELEASE --tag "$ORG/$NAME:$RELEASE-$OS" .
  # docker build --build-arg arg=2.3 .
  # eval docker build --progress=plain ${BUILD_ARGS} ${NOCACHE} --tag $REPO:latest --tag "$REPO:$TAG" .
  echo "jfoo"
  eval docker build --progress=plain ${BUILD_ARGS} ${NOCACHE} --tag $REPO:latest --tag "$REPO:$TAG" .
  echo Push to docker repo in 10 seconds; sleep 10
  echo ${DOCKERHUB_PASSWORD} | docker login -u $DOCKERHUB_USERNAME --password-stdin
  # docker login -u $DOCKERHUB_USERNAME -p ${DOCKERHUB_PASSWORD}  # this is deprecated
  docker push "$REPO:$TAG"
  docker push $REPO:latest
  # docker push "$ORG/$NAME:$RELEASE-$OS"
  docker logout
}

# containers=(
#   "nginx"
#   "http-echo"
# )




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
  # echo ${DOCKERHUB_PASSWORD} | docker login -u ${DOCKERHUB_USERNAME} --password-stdin
  # . "${DOT_ENV_NAME}.env.secrets"

   # ./scripts/process-templates.sh

  # out=$(./scripts/az-login.sh)
  # out=$(./scripts/update_kubectl_host_files.sh $RGRP_NAME $AKS_NAME)

  echo "${INTERNAL_CA_ROOT_CRT}" > uvoo/zabbix-agent2/internal_ca_root.crt

  repos=($(find . -maxdepth 2 -mindepth 2 -type d \
    ! -path "./scripts*" ! -path "./notes*" ! -path "./.git*" \
    ! -path "./tmp*" \
    ! -path "./trash*" ! -path "./.github*" -printf '%P\n'))

  # merge_hash1=$(git log --merges --format="%H" -n 1)
  # merge_hash2=$(git log --merges --format="%H" -n 2 | tail -1)
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  # merge_hash1=$(git log ${current_branch} --first-parent --merges --format="%H" -n 1)
  # merge_hash2=$(git log ${current_branch} --first-parent --merges --format="%H" -n 2 | tail -1)
  merge_hash1=$(git log main --first-parent --merges --format="%H" -n 1)
  merge_hash2=$(git log main --first-parent --merges --format="%H" -n 2 | tail -1)
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
    #   container_build_push "${repo}" "${version}"
      BUILD_ARGS=""
      NOCACHE=""
      if [ -f .env ]; then
        . .env
      fi
      ../../scripts/process-templates.sh
      docker_build_push "${repo}" "${version}"
      cd ../../
    fi
  done
}


oldmain(){
  for container in "${containers[@]}"; do
    cd $container
    # [ $(git diff @^ ./ | wc -l) -eq 0 ] && continue
    echo "Building container $container & pushing to dockerhub."
    # if test -f ".env"; then
    #   . .env
    # fi
    . .env
    ../scripts/process-templates.sh
    docker_build_push
    cd ../
  done
}

main
