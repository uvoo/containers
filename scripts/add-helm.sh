#!/bin/sh
set -e
# https://get.helm.sh/helm-v3.10.3-linux-amd64.tar.gz
# https://get.helm.sh/helm-v3.10.3-linux-arm64.tar.gz.sha256sum
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

helm plugin install https://github.com/databus23/helm-diff
