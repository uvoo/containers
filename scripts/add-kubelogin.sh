#!/bin/sh
set -eu
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 v0.0.25"
  exit
fi

version=$1
name="kubelogin-linux-amd64"
sha256=$(curl -sL "https://github.com/Azure/kubelogin/releases/download/${version}/${name}.zip.sha256")
curl -sLO "https://github.com/Azure/kubelogin/releases/download/${version}/$name.zip"
echo "${sha256}" | sha256sum --check
unzip "${name}.zip"
mv bin/linux_amd64/kubelogin /usr/local/bin/
