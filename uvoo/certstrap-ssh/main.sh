#!/bin/bash
set -eu
echo "Starting certstrap-sshd."

file="${USERDIR}/.ssh/authorized_keys"
if [[ -v AUTHORIZED_KEYS ]]; then
    echo "${AUTHORIZED_KEYS}" | sudo -u ${USERNAME} tee > $file
fi

if [[ -v USERPASSWORD ]]; then
  echo "Setting ${USERNAME} password."
  set +x && echo "${USERNAME}:${USERPASSWORD}" | chpasswd
fi

/usr/sbin/sshd -D -e
