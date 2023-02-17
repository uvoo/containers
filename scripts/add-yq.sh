#!/bin/sh
# https://github.com/mikefarah/yq/releases
# https://mikefarah.gitbook.io/yq/v/v4.x/
set -eu
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 v4.30.8"
  exit
fi
version=$1

curl -sLO "https://github.com/mikefarah/yq/releases/download/${version}/yq_linux_amd64.tar.gz"
tar xf yq_linux_amd64.tar.gz
# chmod +x yq_linux_amd64
mv yq_linux_amd64 /usr/local/bin/yq
