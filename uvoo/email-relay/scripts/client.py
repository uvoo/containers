#!/usr/bin/python3
import smtplib
# import ssl
import email.message
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
import email.utils as utils

def send_html_email(subject, msg_text,
                    toaddrs=['jeremybusk@gmail.com']):
    fromaddr = 'no-reply@uvoo.me'

    msg = "\r\n".join([
        "From: " + fromaddr,
        "To: " + ",".join(toaddrs),
        "Subject: " + subject,
        "",
        msg_text
    ])

    msg = email.message.Message()
    msg['message-id'] = utils.make_msgid(domain='uvoo.me')
    msg['Subject'] = subject
    msg['From'] = fromaddr
    msg['To'] = ",".join(toaddrs)
    msg.add_header('Content-Type', 'text/html')
    msg.set_payload(msg_text)

    username = fromaddr
    username = "tester@localhost" 
    password = 'foo'
    password = 'PleaseChangeMe'
    # server = smtplib.SMTP('localhost',1587)
    server = smtplib.SMTP('localhost',8025)
    #server.ehlo() <- not required for my domain.
    server.starttls()
    server.login(username, password)
    server.sendmail(fromaddr, toaddrs, msg.as_string())
    server.quit()

send_html_email("test", "body txt")
