#!/bin/bash

# Variables
CERT_NAME="test-tls"
NAMESPACE="default"  # Change to your desired namespace
KEY_FILE="tls.key"
CERT_FILE="tls.crt"

# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout $KEY_FILE -out $CERT_FILE \
  -subj "/CN=example.com/O=example-org"

# Create Kubernetes secret
kubectl create secret tls $CERT_NAME \
  --key=$KEY_FILE --cert=$CERT_FILE \
  -n $NAMESPACE

# Clean up local files
rm $KEY_FILE $CERT_FILE

echo "TLS secret '$CERT_NAME' created in namespace '$NAMESPACE'."
echo "sudo cp ca.crt /usr/local/share/ca-certificates/"
echo "sudo update-ca-certificates"
