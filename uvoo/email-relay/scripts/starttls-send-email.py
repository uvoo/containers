#!/usr/bin/python3
import smtplib
from email.mime.text import MIMEText

from_addr = f"noreply@example.com"
to_addr = f"to-email@example.org"
subject = "Test 587"
body = "This is a test email using starttls."

msg = MIMEText(body)
msg["Subject"] = subject
msg["From"] = from_addr
msg["To"] = to_addr

server = smtplib.SMTP("relay.example.com", 587)
server.starttls()
server.send_message(msg)
server.quit()

print("Email sent.")
