#!/bin/bash
set -eu

ssh-keygen -t ed25519 -f ssh_host_ed25519_key -q -N ""
ssh-keygen -t rsa -f ssh_host_rsa_key -q -N ""
ssh-keygen -t ecdsa -f ssh_host_ecdsa_key -q -N ""
