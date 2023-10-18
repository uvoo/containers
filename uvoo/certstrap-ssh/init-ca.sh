#!/bin/bash
set -eux
certstrap init --passphrase "" --common-name Root --exclude-path-length
# certstrap init --passphrase "" --common-name Root --path-length 1
certstrap request-cert --passphrase "" --common-name Intermediate
certstrap sign Intermediate --CA Root --intermediate
certstrap request-cert --passphrase "" --common-name Certificate
certstrap sign Certificate --CA Intermediate
cat out/Root.crt > out/chain.cert.pem
cat out/Intermediate.crt >> out/chain.cert.pem
openssl verify -CAfile out/chain.cert.pem out/Certificate.crt
