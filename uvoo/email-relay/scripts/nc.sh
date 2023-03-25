#!/bin/bash
set -eu
# telnet localhost 8025 <<EOF
# ehlo mail.example.com
# quit
# EOF

BODY="open realy smtp test"
SMTPSRV="localhost"
SMTPPORT="8025"
RCPT="name@domain"
SRC="name@domain"

mail2(){
/bin/nc ${SMTPSRV} ${SMTPPORT} << EOL
ehlo example_domain.com
mail from:${SRC}
RCPT to:${RCPT}
data
From:${SRC}
To:${RCPT}
subject: Telnet test
${BODY}
.
quit
EOL
}


mail(){
/bin/nc ${SMTPSRV} ${SMTPPORT} << EOL
ehlo example_domain.com
quit
EOL
}

mail
