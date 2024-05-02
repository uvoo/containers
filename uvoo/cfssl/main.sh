#!/bin/bash
set -eu
echo "Starting ucfssl server ..."

./init-cfssl-ca.sh
cfssl serve -db-config=db-config.json -ca=ca/ica1.crt -ca-key=ca/ica1.key.crt -config=config.json  -address=0.0.0.0 -port=3000
