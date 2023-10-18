#!/bin/bash
set -eux
echo "Starting certstrap-ssh."

file="${APP_USERDIR}/.ssh/authorized_keys"
if [[ -v AUTHORIZED_KEYS ]]; then
    sudo -u ${APP_USERNAME} mkdir -p ~/.ssh 
    echo "${AUTHORIZED_KEYS}" | sudo -u ${APP_USERNAME} tee $file
fi

if [[ -v USERPASSWORD ]]; then
  echo "Setting ${APP_USERNAME} password."
  set +x && echo "${APP_USERNAME}:${APP_USERPASSWORD}" | chpasswd
fi

/usr/sbin/sshd -D -e
