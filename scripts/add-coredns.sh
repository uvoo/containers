#!/bin/sh
set -eu
## https://github.com/coredns/coredns

release="${1}"

file="coredns_${release}_linux_amd64.tgz"
url_prefix="https://github.com/coredns/coredns/releases/download/v${release}/"

sha256=$(curl -sL "${url_prefix}${file}.sha256")
curl -sLO "${url_prefix}${file}"
echo "${sha256}" | sha256sum --check
tar xf "${file}" && rm "${file}"
mv coredns /usr/local/bin/
