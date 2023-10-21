#!/bin/bash
set -eux
: '
ICA - Intermediate Certificate Autority
RootCA - Root Certificate Authority
First numeric is for unique identification of RootCA or ICA. 
Letter after number is the generation release of the specific ICA.

RootCA1 - Root for everything.
ICA1a - General purpose Intermediate Certificate version 1.
ICA2a - HTTPS applications. 
ICA3a - Host/BackEnd certificates for WINRM and other services.
ICA4a - Client certificates for client applications.
'
certstrap init --common-name RootCA1 --exclude-path-length
# certstrap init --passphrase "" --common-name RootCA1 --path-length 1 
certstrap request-cert --common-name ICA1a 
certstrap sign ICA1a --CA RootCA1 --intermediate
certstrap request-cert --common-name ExampleCertificate
certstrap sign ExampleCertificate --CA ICA1a
cat out/RootCA1.crt > out/ICA1a.chain
cat out/ICA1a.crt >> out/ICA1a.chain
openssl verify -CAfile out/ICA1a.chain out/ExampleCertificate.crt
