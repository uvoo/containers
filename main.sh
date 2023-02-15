#!/usr/bin/env bash
set -eu

docker_build_push(){
  # nocache="--no-cache"
  nocache=""
  docker build $nocache --tag $ORG/$NAME:latest --tag $ORG/$NAME:$RELEASE --tag "$ORG/$NAME:$RELEASE-$OS" .
  echo Push to docker repo in 10 seconds; sleep 10
  echo $DOCKERHUB_USERTOKEN | docker login -u $DOCKERHUB_USERNAME --password-stdin
  docker push $ORG/$NAME:$RELEASE
  docker push $ORG/$NAME:latest
  docker push "$ORG/$NAME:$RELEASE-$OS"
  docker logout
}

containers=(
  "nginx"
  "http-echo"
)

main(){
  for container in "${containers[@]}"; do
    cd $container
    # [ $(git diff @^ ./ | wc -l) -eq 0 ] && continue
    echo "Building container $container & pushing to dockerhub."
    . .env
    ../scripts/process-templates.sh
    docker_build_push
    cd ../
  done
}

main
