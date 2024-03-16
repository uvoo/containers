#!/bin/bash
set -eu
echo "Starting certstrap-ssh."k -n cert

# . .env
# . .env.secrets
./init-cfssl-ca.sh
# cfssl serve -db-config=db-config.json -ca=certificates/localhost.pem -ca-key=certificates/localhost-key.pem -config=config.json  -address=0.0.0.0 -port=3000
cfssl serve -db-config=db-config.json -ca=intermediate/intermediate-ca.pem -ca-key=intermediate/intermediate-ca-key.pem -config=config.json  -address=0.0.0.0 -port=3000


# cd cf
# cd /app/cfssl-ca
# sleep 1000
# cfssl serve -db-config=sqlite_db.json -ca=server/server.pem -ca-key=server/server-key.pem -config=config.json
