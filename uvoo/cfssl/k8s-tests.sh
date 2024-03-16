AUTH="admin:admin"
URI_BASE="https://192.168.254.19:8443"

getRootDir(){
  curl -sku $AUTH $URI_BASE
}

getInfo(){
  curl -sku $AUTH -d '{}' -H "Content-Type: application/json" -X POST  $URI_BASE/api/v1/cfssl/info | jq -r .result.certificate | openssl x509 -text
}


getNewCert(){
  openssl genrsa -out example.key 2048

  # Generate a CSR
  openssl req -new -key example.key -out example.csr -subj "/CN=example.com"

  # Prepare JSON payload for CFSSL
cat <<EOF > csr.json
{
  "request": {
    "hosts": [
      "example.com",
      "127.0.0.1"
    ],
    "CN": "example.com",
    "key": {
      "algo": "rsa",
      "size": 2048
    },
    "names": [
      {
        "C": "US",
        "ST": "California",
        "L": "Los Angeles",
        "O": "Example Inc.",
        "OU": "IT"
      }
    ]
  }
}
EOF
  curl -sku $AUTH -X POST -d @csr.json $URI_BASE/api/v1/cfssl/newcert | jq -r .result.certificate | openssl x509 -text
}

getNewCert
