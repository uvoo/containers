#!/bin/bash
set -aeu

if test -f ca/initialized; then
  exit 0
fi

goose version
goose up
goose status

mkdir -p ca certificates
cd ca
cat <<EOF > db-config.json
  {"driver":"$GOOSE_DRIVER","data_source":"$GOOSE_DBSTRING"}
EOF

cat <<EOF > root-csr.json
{
  "CN": "${ROOT_CN}",
  "key": {
    "algo": "${ALGO}",
    "size": ${ALGOSIZE}
  },
  "names": [
    {
      "C": "${C}",
      "O": "${O}",
      "OU": "${OU}"
    }
  ],
  "ca": {
    "expiry": "${ROOT_EXPIRE_HOURS}"
  }
}
EOF

cfssl gencert -initca root-csr.json \
  | cfssljson -bare rootca1 -cert
mv rootca1.pem rootca1.crt
mv rootca1-key.pem rootca1.key

openssl rsa -aes256 -in rootca1.key -passout pass:$ROOT_CA_PASS -out rootca1.key.enc

cat << EOF > ica1-csr.json
{
  "CN": "${INTERMEDIATE_CN}",
  "key": {
    "algo": "${ALGO}",
    "size": ${ALGOSIZE}
  },
  "names": [
    {
      "C": "${C}",
      "O": "${O}",
      "OU": "${OU}"
    }
  ]
}
EOF

cfssl genkey ica1-csr.json \
  | cfssljson -bare ica1

cat << EOF > ocsp-csr.json
{
  "CN": "OCSP Signer",
  "key": {
    "algo": "${ALGO}",
    "size": ${ALGOSIZE}
  },
  "names": [
    {
      "C": "${C}",
      "O": "${O}",
      "OU": "${OU}"
    }
  ]
}
EOF

cat << EOF > config.json
  "signing": {
    "default": {
      "ocsp_url": "http://localhost:8889",
      "crl_url": "http://localhost:8888/crl",
      "expiry": "${DEFAULT_EXPIRE_HOURS}",
      "usages": [
        "signing",
        "key encipherment",
        "client auth"
      ]
    },
    "profiles": {
      "root_ca": {
        "usages": [
          "signing",
          "digital signature",
          "key encipherment",
          "cert sign",
          "crl sign",
          "server auth",
          "client auth"
        ],
        "expiry": "${ROOT_EXPIRE_HOURS}",
        "ca_constraint": {
          "is_ca": true,
          "max_path_len": 1,
          "max_path_len_zero": false
        }
      },
      "intermediate_ca": {
        "usages": [
          "signing",
          "digital signature",
          "key encipherment",
          "cert sign",
          "crl sign",
          "server auth",
          "client auth"
        ],
        "expiry": "${INTERMEDIATE_EXPIRE_HOURS}",
        "ca_constraint": {
          "is_ca": true,
          "max_path_len": 0,
          "max_path_len_zero": true
        }
      },
      "peer": {
        "usages": [
          "signing",
          "digital signature",
          "key encipherment",
          "client auth",
          "server auth"
        ],
        "expiry": "${PEER_EXPIRE_HOURS}"
      },
      "server": {
        "usages": [
          "signing",
          "digital signing",
          "key encipherment",
          "server auth"
        ],
      "expiry": "${SERVER_EXPIRE_HOURS}"
      },
      "client": {
        "usages": [
          "signing",
          "digital signature",
          "key encipherment",
          "client auth"
        ],
        "expiry": "${CLIENT_EXPIRE_HOURS}"
      },
      "host": {
        "usages": [
          "signing",
          "digital signing",
          "key encipherment",
          "server auth"
        ],
        "expiry": "${HOST_EXPIRE_HOURS}"
      },
      "ocsp": {
        "usages": ["digital signature", "ocsp signing"],
        "expiry": "${OSCP_EXPIRE_HOURS}"
      }
    }
  }
}
EOF

cat << EOF > ocsp-csr.json
{
  "CN": "OCSP signer",
  "key": {
    "algo": "ecdsa",
    "size": 256
  },
  "names": [
    {
      "C": "${C}",
      "O": "${O}",
      "OU": "${OU}"
    }
  ]
}
EOF

cfssl sign -ca rootca1.crt \
  -ca-key rootca1.key \
  -config config.json \
  -profile root_ca \
  ica1.csr \
  | cfssljson -bare ica1
mv ica1.pem ica1.crt
mv ica1-key.pem ica1.key

cfssl gencert -ca ica1.crt \
  -ca-key ica1.key \
  -config config.json -profile="ocsp" ocsp-csr.json \
  | cfssljson -bare server-ocsp -

openssl rsa -aes256 -in ica1.key -passout pass:$INTERMEDIATE_CA_PASS -out ica1.key.enc
cd ../

cat << EOF > certificates/my-webserver-csr.json
{
  "CN": "my-webserver.example.com",
  "hosts": ["my-webserver.example.com", "192.168.1.20"],
  "names": [
    {
      "C": "US",
      "L": "Lehi",
      "S": "Utah",
      "O": "Example",
      "OU": "IT"
    }
  ]
}
EOF

cat << EOF > certificates/localhost.json
{
  "CN": "localhost",
  "key": {
    "algo": "rsa",
    "size": 4096
  },
  "names": [
  {
    "C": "US",
    "L": "Lehi",
    "S": "Utah",
    "O": "Example",
    "OU": "IT"
  }
  ],
  "hosts": [
    "127.0.0.1",
    "localhost"
  ]
}
EOF

cd ca

cfssl gencert -ca ica1.crt -ca-key ica1.key -config config.json -profile=server ../certificates/localhost.json | cfssljson -bare ../certificates/localhost

# Remove encrypted keys
rm rootca1.key
rm ica1.key

# TEST
cat rootca1.crt ica1.crt > ica1.chain.crt
openssl verify -CAfile ica1.chain.crt ../certificates/localhost.pem

date > initialized


# More Tests
# curl -v https://localhost
# host=localhost; port=443; echo quit | openssl s_client -showcerts -servername server -connect $host:$port | grep subject
# host=localhost; port=443; echo "" | openssl s_client -connect ${host}:${port} 2>&1 | grep -A 6 "Certificate chain"
