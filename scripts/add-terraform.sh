#!/bin/sh
set -eu
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <terraform version>"
  echo "Example: $0 1.3.6"
  exit
fi

version=$1
curl -sLO https://releases.hashicorp.com/terraform/${version}/terraform_${version}_SHA256SUMS
curl -sLO https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_amd64.zip
sha256_sig=$(cat terraform_${version}_SHA256SUMS | grep terraform_${version}_linux_amd64.zip | cut -d " " -f 1)
sha256_file=$(sha256sum terraform_${version}_linux_amd64.zip | awk '{print $1}')
if [ ! "${sha256_file}" = "${sha256_sig}" ]; then
  echo "I: The sha256 for file does not match signature from web. Check file integrity."
  exit 1
fi
unzip terraform_${version}_linux_amd64.zip
mv terraform /usr/local/bin/

# apt way
#  wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
# echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
# sudo apt update && sudo apt install -y terraform
