#!/bin/bash
set -aeu
. .env.secrets

cd ${PWD}
openssl rand -writerand .rnd
OPENSSL_CA_DIR=openssl_ca
mkdir -p ${OPENSSL_CA_DIR}
mkdir -p ${OPENSSL_CA_DIR}/certs
mkdir -p ${OPENSSL_CA_DIR}/crl
mkdir -p ${OPENSSL_CA_DIR}/private
if [ ! -e ${OPENSSL_CA_DIR}/serial ]; then
  echo 0100 > ${OPENSSL_CA_DIR}/serial
fi
if [ ! -e ${OPENSSL_CA_DIR}/index ]; then
  touch ${OPENSSL_CA_DIR}/index
fi

# cat << 'EOF' > ${OPENSSL_CA_DIR}/openssl.cnf
# cat << 'EOF' > /home/busk/openssl_ca/openssl.cnf
cat << 'EOF' > ./openssl_ca/openssl.cnf
HOME                      = .
RANDFILE                  = $ENV::HOME/.rnd

[ ca ]
default_ca                = CA_default

[ CA_default ]
# dir                       = /opt/openssl_ca
dir                       = /home/busk/openssl_ca
crl_dir                   = $dir/crl
database                  = $dir/index
new_certs_dir             = $dir/certs
serial                    = $dir/serial
# certificate               = $dir/issuer.crt
certificate               = $dir/RootCA1.crt
private_key               = $dir/RootCA1.key
# certificate               = $dir/ICA1a.crt
# private_key               = $dir/ICA1a.key
# private_key               = $dir/private/issuer.key
# private_key               = $dir/private/ICA1a.key
policy                    = policy_match
default_days              = 365           # 1 year
default_crl_days          = 7             # 7 days
default_md                = sha1
default_bits              = 2048
preserve                  = no
unique_subject            = no
x509_extensions           = v3_req
copy_extensions           = copy          # to enable SubjectAltName

[ policy_match ]
countryName               = optional
stateOrProvinceName       = optional
localityName              = optional
organizationName          = supplied
organizationalUnitName    = optional
commonName                = optional

[ req ]
distinguished_name        = req_distinguished_name

[ req_distinguished_name ]
countryName               = Country (2 letter code)
countryName_min           = 2
countryName_max           = 2
stateOrProvinceName       = State or Province (spelled out)
localityName              = City or Locality
organizationName          = Organization
organizationalUnitName    = Organizational Unit
commonName                = Common Name (FQDN)
commonName_max            = 64

[ v3_req ]
basicConstraints          = CA:FALSE
subjectKeyIdentifier      = hash
authorityKeyIdentifier    = keyid,issuer
keyUsage                  = digitalSignature,keyEncipherment
extendedKeyUsage          = serverAuth,clientAuth
crlDistributionPoints     = URI:http://pki.venafi.example/issuer.crl

[ v3_ca ]
basicConstraints          = CA:TRUE
subjectKeyIdentifier      = hash
authorityKeyIdentifier    = keyid:always,issuer:always
keyUsage                  = cRLSign,keyCertSign

[ v3_intermediate_ca ]
basicConstraints          = CA:TRUE
subjectKeyIdentifier      = hash
authorityKeyIdentifier    = keyid:always,issuer:always
keyUsage                  = cRLSign,keyCertSign
EOF

cd ${OPENSSL_CA_DIR}

# RootCA1
openssl genrsa -passout env:ROOTCA1_PWD -aes256 -out RootCA1.key 4096
openssl req -passin env:ROOTCA1_PWD -config openssl.cnf \
            -extensions v3_ca \
            -key RootCA1.key \
            -new -x509 -days 3653 -sha256 -extensions v3_ca \
            -out RootCA1.crt -subj "/C=US/ST=Utah/L=SLC/O=ExampleCorp/OU=Testing/CN=RootCA1"
openssl x509 -noout -text -in RootCA1.crt


# IntermediateCA ICA1a
openssl genrsa -passout env:ICA1a_PWD -aes256 -out ICA1a.key 4096
openssl req -passin env:ICA1a_PWD -config openssl.cnf \
            -new -sha256 \
            -key ICA1a.key \
            -out ICA1a.csr -subj "/C=US/ST=Utah/L=SLC/O=ExampleCorp/OU=Testing/CN=ICA1a"
yes | openssl ca -passin env:ROOTCA1_PWD -config openssl.cnf \
           -extensions v3_intermediate_ca \
           -days 1826 -notext -md sha256 \
           -in ICA1a.csr \
           -out ICA1a.crt
openssl x509 -text -in ICA1a.crt
openssl x509 -text -in certs/0100.pem

echo "Completed successfully!"
cd ../
