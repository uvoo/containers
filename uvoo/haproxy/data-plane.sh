#!/bin/bash
set -eux

DATAPLANE_MINOR=2.7.2
DATAPLANE_URL=https://github.com/haproxytech/dataplaneapi.git
# GOPATH=/usr/local/go
mkdir -p /tmp
GOPATH=/tmp

git clone "${DATAPLANE_URL}" "${GOPATH}/src/github.com/haproxytech/dataplaneapi"
cd "${GOPATH}/src/github.com/haproxytech/dataplaneapi"
git checkout "v${DATAPLANE_MINOR}"
go mod tidy
make build && cp build/dataplaneapi /tmp/dataplaneapi
