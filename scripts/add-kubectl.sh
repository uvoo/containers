#!/bin/sh
# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux
set -e

if [ $1 ]; then
  version=$1
else
  version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
fi

curl -sLO "https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl"
curl -sLO "https://dl.k8s.io/${version}/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
chmod +x kubectl
mv kubectl /usr/local/bin/
# kubectl version
# ./kubectl version
# install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
