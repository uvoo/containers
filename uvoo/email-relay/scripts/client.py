#!/usr/bin/python3
import argparse
import smtplib
# import ssl
import email.message
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
import email.utils as utils


# def main():

parser = argparse.ArgumentParser(description='Send email')
# parser.add_argument('hostname', metavar='H', type=str,
parser.add_argument('-u', '--username', required=True, type=str,
                    default='tester@localhost',
                    help='SMTP Auth full username')
parser.add_argument('-p', '--password', required=True, type=str,
                    default='PleaseChangeMe',
                    help='SMTP Auth password')
parser.add_argument('-H', '--host', required=True, type=str,
                    default='localhost',
                    help='SMTP Auth host in FQDN format.')
parser.add_argument('-P', '--port', required=True, type=str,
                    default='8587',
                    help='SMTP Auth submission port.')
parser.add_argument('-f', '--fromaddr', required=True, type=str,
                    help='Email from address.')
parser.add_argument('-t', '--toaddrs', nargs='+', required=True,
                    help='Email to address.')
parser.add_argument('-s', '--subject', required=False, type=str,
                    default='test',
                    help='Email subject text.')
parser.add_argument('-b', '--body', required=False, type=str,
                    default='test',
                    help='Email body text.')
parser.add_argument('-n', '--notls', action='store_true',
                    help="Don't use tls transport encryption.")

args = parser.parse_args()
# hostname = args.hostname

def send_html_email(subject, body, toaddrs, fromaddr, host, port, username, password, notls):
# def send_html_email(args.subject, args.msg_text,
#                     toaddrs=['jeremybusk@gmail.com']):
                    # toaddrs=['jeremybusk@gmail.com']):
    # fromaddr = 'no-reply@uvoo.me'
    # username=fromaddr.split("@")[0]
    domain=fromaddr.split("@")[1]

    msg = "\r\n".join([
        "From: " + fromaddr,
        "To: " + ",".join(toaddrs),
        "Subject: " + subject,
        "",
        body
    ])

    msg = email.message.Message()
    msg['message-id'] = utils.make_msgid(domain=domain)
    msg['Subject'] = subject
    msg['From'] = fromaddr
    msg['To'] = ",".join(toaddrs)
    msg.add_header('Content-Type', 'text/html')
    msg.set_payload(body)

    # username = fromaddr
    # username = "tester@localhost" 
    # password = 'foo'
    # password = 'PleaseChangeMe'
    # server = smtplib.SMTP('localhost',1587)
    server = smtplib.SMTP(host, port)
    #server.ehlo() <- not required for my domain.
    if not notls:
      server.starttls()
    server.login(username, password)
    server.sendmail(fromaddr, toaddrs, msg.as_string())
    server.quit()

# send_html_email("test", "Test message.")
send_html_email(args.subject, args.body, args.toaddrs, args.fromaddr, args.host, args.port, args.username, args.password, args.notls)
