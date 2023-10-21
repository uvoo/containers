# Simple CA Using OpenSSL 

## Getting Started
Copy example env secrets and update with your secrets.
```
cp example.env.secrets .env.secrets
```

Run init to create OpenSSL CA folder. 
```
./init-openssl-ca.sh
```

# Some of the many docs on OpenSSL CA out there.
- https://www3.rocketsoftware.com/rocketd3/support/documentation/Uniface/10/uniface/security/certificates/createRootCertificate.htm
- https://www3.rocketsoftware.com/rocketd3/support/documentation/Uniface/10/uniface/security/certificates/createIntermediateCertificate.htm

# Alternatives Using OpenSSL
- https://github.com/OpenVPN/easy-rsa
