# CFSSL CA Readme

## Init cfssl sqlite3

Copy examples and edit with your values, especial secrets.
```
cp example.env .env
cp example.env.secrets .env.secrets
```

Run init. files are in cfssl-ca folder.
```
./init-cfssl-ca.sh
```

## HTTP Server
Here is if you want to enable http server
```
cd cfssl-ca
cfssl serve -db-config=db-config.json -loglevel=0  -ca-key=intermediate/intermediate-ca-key.pem -ca=intermediate/intermediate-ca.pem -config=config.json -responder=certificates/server-ocsp.pem -responder-key=certificates/server-ocsp-key.pem
```
