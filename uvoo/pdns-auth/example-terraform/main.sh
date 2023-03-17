#!/bin/bash
set -eu

envtpl --keep-template backend.tf.tpl
. .env.secrets
# versions.tf
terraform plan 
echo "Running apply in 10 seconds." && sleep 10
terraform apply -auto-approve
./test.sh
