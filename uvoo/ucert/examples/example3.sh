#!/bin/bash
set -eu
certstrap init --common-name CA --exclude-path-length
openssl x509 -noout -text -in out/CA.crt

certstrap request-cert --common-name ICA1
certstrap sign ICA1 --CA CA --intermediate --path-length 1
openssl x509 -noout -text -in out/ICA1.crt

certstrap request-cert --common-name ICA2
certstrap sign ICA2 --CA ICA1 --intermediate
openssl x509 -noout -text -in out/ICA2.crt
