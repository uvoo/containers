import sqlite3
import socket
import time
from datetime import datetime, timedelta

# Database setup
DB_FILE = 'greylist.db'

def create_db():
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS greylist
                 (domain TEXT PRIMARY KEY, first_seen TIMESTAMP, status TEXT)''')
    conn.commit()
    conn.close()

def check_or_add_domain(domain):
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute('SELECT domain, first_seen, status FROM greylist WHERE domain = ?', (domain,))
    row = c.fetchone()
    if row:
        first_seen, status = row[1], row[2]
        if status == 'cleared' or datetime.now() - datetime.strptime(first_seen, '%Y-%m-%d %H:%M:%S') > timedelta(hours=24):
            action = 'DUNNO'
        else:
            action = 'DEFER_IF_PERMIT Greylisting in effect for {}, please try again later'.format(domain)
    else:
        c.execute('INSERT INTO greylist (domain, first_seen, status) VALUES (?, ?, ?)',
                  (domain, datetime.now().strftime('%Y-%m-%d %H:%M:%S'), 'greylisted'))
        conn.commit()
        action = 'DEFER_IF_PERMIT Greylisting in effect for {}, please try again later'.format(domain)
    conn.close()
    return action

def handle_client(connection):
    data = connection.recv(1024).decode('utf-8')
    lines = data.split('\n')
    recipient = None
    for line in lines:
        if line.startswith('recipient='):
            recipient = line.split('=')[1].strip()
            break
    if recipient:
        domain = recipient.split('@')[-1]
        action = check_or_add_domain(domain)
    else:
        action = 'DUNNO'
    response = 'action={}\n\n'.format(action)
    connection.sendall(response.encode('utf-8'))

def main():
    create_db()
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.bind(('127.0.0.1', 10023))
    server_socket.listen(5)
    print('Listening on port 10023...')
    try:
        while True:
            conn, addr = server_socket.accept()
            handle_client(conn)
            conn.close()
    except KeyboardInterrupt:
        print('Shutting down...')
    finally:
        server_socket.close()

if __name__ == '__main__':
    main()
