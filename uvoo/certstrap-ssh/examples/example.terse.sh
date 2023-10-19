#!/bin/bash
set -eux
: '
Root1 - Root for everything version 1
ICA1a - General purpose Intermediate Certificate version 1
ICA2a - HTTPS applications 
ICA3a - Host/BackEnd certificates for WINRM
'
certstrap init --common-name Root1 --exclude-path-length
# certstrap init --passphrase "" --common-name Root --path-length 1
certstrap request-cert --common-name ICA1a 
certstrap sign ICA1a --CA Root1 --intermediate
certstrap request-cert --common-name ExampleCertificate
certstrap sign ExampleCertificate --CA ICA1a
cat out/Root1.crt > out/ICA1a.chain
cat out/ICA1a.crt >> out/ICA1a.chain
openssl verify -CAfile out/ICA1a.chain out/ExampleCertificate.crt
