#!/bin/bash
set -eux
echo "Starting certstrap-ssh."

file="${USERDIR}/.ssh/authorized_keys"
if [[ -v AUTHORIZED_KEYS ]]; then
    sudo -u ${USERNAME} mkdir -p ~/.ssh 
    echo "${AUTHORIZED_KEYS}" | sudo -u ${USERNAME} tee $file
fi

if [[ -v USERPASSWORD ]]; then
  echo "Setting ${USERNAME} password."
  set +x && echo "${USERNAME}:${USERPASSWORD}" | chpasswd
fi

/usr/sbin/sshd -D -e
