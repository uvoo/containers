#!/usr/bin/python3
import smtplib
from email.mime.text import MIMEText

# Email details
from_addr = f"noreply@example.com"
to_addr = f"exampleuser@example.com"
subject = "Test"
body = "This is a test email."

# Create the email
msg = MIMEText(body)
msg["Subject"] = subject
msg["From"] = from_addr
msg["To"] = to_addr

# Send the email
server = smtplib.SMTP("localhost", 8587)
server.send_message(msg)
server.quit()

print("Email sent.")
