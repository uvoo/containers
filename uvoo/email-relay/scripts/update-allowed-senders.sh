#!/bin/bash
set -eu

ALLOWED_DOMAINS=(
  "allowed-example1.com"
  "allowed-example2.com"
)

POSTFIX_MAIN_CF="/etc/postfix/main.cf"
ALLOWED_SENDERS_FILE="/etc/postfix/allowed_senders"

string_in_file() {
  local string="$1"
  local file="$2"
  grep -Fq "$string" "$file"
}

if ! string_in_file "smtpd_sender_restrictions = check_sender_access hash:$ALLOWED_SENDERS_FILE, reject" "$POSTFIX_MAIN_CF"; then
  echo "smtpd_sender_restrictions = check_sender_access hash:$ALLOWED_SENDERS_FILE, reject" | sudo tee -a "$POSTFIX_MAIN_CF"
else
  echo "Sender restrictions already exists in $POSTFIX_MAIN_CF"
fi

sudo touch "$ALLOWED_SENDERS_FILE"
for DOMAIN in "${ALLOWED_DOMAINS[@]}"; do
  ENTRY="@${DOMAIN} OK"
  if ! string_in_file "$ENTRY" "$ALLOWED_SENDERS_FILE"; then
    echo "$ENTRY" | sudo tee -a "$ALLOWED_SENDERS_FILE"
  else
    echo "Domain $DOMAIN already exists in $ALLOWED_SENDERS_FILE"
  fi
done

sudo postmap "$ALLOWED_SENDERS_FILE"

sudo systemctl reload postfix

echo "Done."

