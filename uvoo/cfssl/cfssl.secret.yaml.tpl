---
apiVersion: v1
stringData:
  # GOOSE_DBSTRING=./certs.db
  GOOSE_DBSTRING: postgresql://app:ChangeMe@cfssl-rw.cfssl.svc:5432/app?sslmode=require
  ROOTCA1_PASS: ChangeMe
  ICA1a_PASS: ChangeThis
  ROOT_CA_PASS: ChangeMe
  INTERMEDIATE_CA_PASS: ChangeThis
  # openssl rand -hex 16
  AUTH_KEY1: 7808c86b2a59e3998cc5d65ff0fa9cff
kind: Secret
metadata:
  name: cfssl-env
