#!/usr/bin/env bash
set -eu

processTemplates(){
  for template_file in $(find . -type f -name "*.envsubst"); do
    dst_file="${template_file%.*}"
    echo Processing envsubst file $template_file to $dst_file with env variables.
    envsubst < $template_file > $dst_file
  done
}

echo "${INTERNAL_CA_ROOT_CRT}" > internal_ca_root.crt

. .env
processTemplates

cd alertscripts/ && find . -type f -exec chmod 0500 -- {} + && cd ../
cd externalscripts/ && find . -type f -exec chmod 0500 -- {} + && cd ../

tag=${DST_REPO}:${DST_REPO_TAG}
echo "Build and push docker container to Dockerhub."
echo Using dockerhub user: ${DOCKERHUB_USERNAME}
docker build --tag ${tag} .
echo $DOCKERHUB_USERTOKEN | docker login --username $DOCKERHUB_USERNAME --password-stdin
docker push ${tag}
docker logout
