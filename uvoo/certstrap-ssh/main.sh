#!/bin/bash
set -eu
echo "Starting certstrap-ssh."k -n cert

file="${ADMIN_DIR}/.ssh/authorized_keys"
if [[ -v AUTHORIZED_KEYS ]]; then
  echo "Adding .ssh/authorized_keys file." 
  sudo -u ${ADMIN_USERNAME} mkdir -p ${ADMIN_DIR}/.ssh
  echo "${AUTHORIZED_KEYS}" | sudo -u ${ADMIN_USERNAME} tee $file
fi

if [[ -v ADMIN_PASSWORD ]]; then
  echo "Setting ${ADMIN_USERNAME} password."
  set +x && echo "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" | chpasswd
fi

if [[ -v SSH_HOST_ECDSA_KEY ]]; then
  echo "Adding sshd host keys."
  mkdir -p /etc/sshd_config
  set +x
  echo "${SSH_HOST_ECDSA_KEY_PUB}" > /etc/sshd_config/ssh_host_ecdsa_key.pub
  echo "${SSH_HOST_ECDSA_KEY}" > /etc/sshd_config/ssh_host_ecdsa_key
  chmod 600 /etc/sshd_config/ssh_host_ecdsa_key
  echo "${SSH_HOST_RSA_KEY_PUB}" > /etc/sshd_config/ssh_host_rsa_key.pub
  echo "${SSH_HOST_RSA_KEY}" > /etc/sshd_config/ssh_host_rsa_key
  chmod 600 /etc/sshd_config/ssh_host_rsa_key
  echo "${SSH_HOST_ED25519_KEY_PUB}" > /etc/sshd_config/ssh_host_ed25519_key.pub
  echo "${SSH_HOST_ED25519_KEY}" > /etc/sshd_config/ssh_host_ed25519_key
  chmod 600 /etc/sshd_config/ssh_host_ed25519_key
fi

/usr/sbin/sshd -D -e
