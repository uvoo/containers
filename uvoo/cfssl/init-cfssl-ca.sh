#!/bin/bash
set -aeu
# . .env
# . .env.secrets

# init_postgres () {
# cat << EOF | sudo -Hiu postgres psql
# CREATE ROLE ${PGUSER} WITH login PASSWORD '${PGPASSWORD}';
# CREATE DATABASE ${PGDATABASE} OWNER ${PGUSER};
# grant all privileges on database ${PGDATABASE} to ${PGUSER};
# EOF
# }
# init_postgres

if test -f initialized; then
  exit 0
fi

goose version
goose up
goose status

# mkdir -p ${OUT_DIR}
# cd ${OUT_DIR}
mkdir -p root intermediate certificates

cat <<EOF > db-config.json
  {"driver":"sqlite3","data_source":"certs.db"}
EOF

cat <<EOF > root/root-csr.json
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

cfssl gencert -initca root/root-csr.json \
| cfssljson -bare root/root-ca

cat << EOF > intermediate/intermediate-csr.json
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

cfssl genkey intermediate/intermediate-csr.json \
| cfssljson -bare intermediate/intermediate-ca

cat << EOF > certificates/ocsp.csr.json
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
{
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
          "max_path_len": 2,
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
  },
  "auth_keys": {
    "key1": {
      "type":"standard",
      "key": "${AUTH_KEY1}"
	  }
  }
}
EOF

cat << EOF > ocsp.csr.json
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

cfssl sign -ca root/root-ca.pem \
  -ca-key root/root-ca-key.pem \
  -config config.json \
  -profile root_ca \
  intermediate/intermediate-ca.csr \
| cfssljson -bare intermediate/intermediate-ca

cfssl gencert -ca intermediate/intermediate-ca.pem \
        -ca-key intermediate/intermediate-ca-key.pem \
        -config config.json -profile="ocsp" ocsp.csr.json \
        | cfssljson -bare certificates/server-ocsp -

    #     "default": {
    #         "ocsp_url": "http://localhost:8889",
    #         "crl_url": "http://localhost:8888/crl",
    #         "expiry": "${DEFAULT_EXPIRE_HOURS}",
    #         "usages": [
    #             "signing",
    #             "key encipherment",
    #             "client auth"
    #         ]
    #     },


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

cfssl gencert -ca intermediate/intermediate-ca.pem -ca-key intermediate/intermediate-ca-key.pem -config config.json -profile=server certificates/localhost.json | cfssljson -bare certificates/localhost

# TEST
cat root/root-ca.pem > intermediate.chain.pem
cat intermediate/intermediate-ca.pem >> intermediate.chain.pem
openssl verify -CAfile intermediate.chain.pem certificates/localhost.pem

# OTHER
# cp certificates/localhost-key.pem /etc/nginx/certs/localhost.key
# cat certificates/localhost.pem intermediate/intermediate-ca.pem root/root-ca.pem > /etc/nginx/certs/localhost.crt
# sudo cp root/root-ca.pem /usr/local/share/ca-certificates/testroot.crt
# sudo update-ca-certificates

# cd ..

date > initialized


# More Tests
# curl -v https://localhost
# host=localhost; port=443; echo quit | openssl s_client -showcerts -servername server -connect $host:$port | grep subject
# host=localhost; port=443; echo "" | openssl s_client -connect ${host}:${port} 2>&1 | grep -A 6 "Certificate chain"


