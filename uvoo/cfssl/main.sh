#!/bin/bash
set -eu
echo "Starting ucfssl server ..."

./init-cfssl-ca.sh
openssl rsa -in ca/ica1.key.enc -out ica1.key -aes256 -passin pass:$INTERMEDIATE_CA_PASS
cfssl serve -db-config=db-config.json -ca=ca/ica1.crt -ca-key=ica1.key -config=config.json  -address=0.0.0.0 -port=3000
