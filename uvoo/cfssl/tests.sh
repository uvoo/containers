# Generate a private key
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

curl -d '{}' -H "Content-Type: application/json" -X POST localhost:3000/api/v1/cfssl/info | jq -r .result.certificate | openssl x509 -text

curl -s -X POST -d @csr.json http://localhost:3000/api/v1/cfssl/newcert | jq -r .result.certificate | openssl x509 -text

exit

# curl -s -X POST -d @csr.json http://localhost:3000/api/v1/cfssl/sign
# exit

# curl http://localhost:3000/api/v1/cfssl/crl

# Send CSR to CFSSL API
# curl -X POST -d @csr.json http://localhost:3000/api/v1/cfssl/newcert -o cert.pem
# curl -X POST -d @csr.json http://localhost:3000/api/v1/cfssl/newcert


# Define the paths to your files
openssl req -newkey ec:ca_cert.pem -keyout ca_key.pem -out csr.pem
csr_file="csr.pem"
ca_cert_file="ca_cert.pem"
ca_key_file="ca_key.pem"

# Construct the JSON payload
json_payload=$(cat <<EOF
{
  "certificate_request": "$(cat "$csr_file")",
  "issuer": {
    "ca_cert": "$(cat "$ca_cert_file")",
    "ca_key": "$(cat "$ca_key_file")"
  }
}
EOF
)

# Send the JSON payload to the /sign endpoint
curl -X POST -d "$json_payload" http://localhost:3000/api/v1/cfssl/sign
