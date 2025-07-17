#!/bin/bash
set -eu
. ../includes/main.sh

# envtpl --keep-template secret.yaml.tpl
# kubectl_apply "-f secret.yaml"

envsubst < override.values.yaml.envsubst > override.values.yaml
helm_upgrade "--install syslog bitnami/fluent-bit -f override.values.yaml"
if [[ -v CI_APPLY ]]; then
  kubectl rollout restart deploy/syslog-fluent-bit
fi
