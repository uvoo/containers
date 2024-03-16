---
apiVersion: v1
stringData:
  ROOTCA1_PASS: ChangeMe
  ICA1a_PASS: ChangeThis
  # openssl rand -hex 16
  AUTH_KEY1: 7808c86b2a59e3998cc5d65ff0fa9cff
kind: Secret
metadata:
  name: cfssl-env
