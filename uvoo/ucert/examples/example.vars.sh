#!/bin/bash
set -eux
ROOT1_CN="ExampleOrg Root R1"
ICA_R1_CN="ExampleOrg ICA R1"
ICA_WEB_R1_CN="ExampleOrg ICA Web R1"
ICA_HOST_R1_CN="ExampleOrg ICA Host R1"
certstrap init --common-name "${ROOT1_CN}" --exclude-path-length
# certstrap init --passphrase "" --common-name Root --path-length 1
certstrap request-cert --common-name  "${ICA_R1_CN}"
certstrap sign "$ICA_R1_CN" --CA "$ROOT1_CN" --intermediate
certstrap request-cert --common-name ExampleCertificate
certstrap sign ExampleCertificate --CA "${ICA_R1_CN}"
cat out/ExampleOrg_Root_R1.crt > out/ExampleOrg_ICA_R1.chain.cert.pem
cat out/ExampleOrg_ICA_R1.crt >> out/ExampleOrg_ICA_R1.chain.cert.pem
openssl verify -CAfile out/ExampleOrg_ICA_R1.chain.cert.pem out/ExampleCertificate.crt
