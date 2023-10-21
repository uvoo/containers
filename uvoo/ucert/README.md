# Getting Started

## Build & Run Docker Instance

Generate your unique sshd keys for docker container
```
./gen-sshhost-keys.sh
```

```
docker build -t certstrap-ssh .
```

```
docker run -ti --rm --name certstrap-ssh \
  -e AUTHORIZED_KEYS="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDH+lInMxgZQ75BFtSfWuLZDpjqWBU+6orFw5cQPj+em" certstrap-ssh
```

## Exec Into Running Container
```
docker exec -it certstrap-ssh bash
```

## SSH INTO APPLICATION

Find ip address from
```
docker inspect certstrap-ssh
```

SSH to host
```
ssh app@172.17.0.5
```

For editing init-ca.sh the vim and nano editors are included.

If you ls -lhat /app/examples/ you can get different example sh templates to copy to your folder and run.


## Running init-ca.sh
Init basic Certificate Authority with init-ca.sh script
```
./init-ca.sh
```

All your certificates are in the "out" directory

Case sensitive duplicate certifcates are not permited. Underscores are added for spaces in names.

Generating random passwords from shell
```
< /dev/urandom tr -dc A-Za-z0-9 | head -c32
tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' </dev/urandom | head -c 32  ; echo
```






# Root & Intermediate
- https://github.com/istio/istio/issues/17609
```
certstrap init --passphrase "" --common-name Root
certstrap request-cert --passphrase "" --common-name Intermediate
certstrap sign Intermediate --CA Root --intermediate
certstrap request-cert --passphrase "" --common-name Certificate
certstrap sign Certificate --CA Intermediate
cat out/Root.crt > out/chain.cert.pem
cat out/Intermediate.crt >> out/chain.cert.pem
openssl verify -CAfile out/chain.cert.pem out/Certificate.crt
```
