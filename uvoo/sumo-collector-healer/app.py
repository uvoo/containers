#!/usr/bin/env python3
import ipaddress
import logging
import os
import socket
from subprocess import PIPE, run
import time

import requests
from requests.auth import HTTPBasicAuth

SUMO_ACCESS_ID = os.environ.get('SUMO_ACCESS_ID')
SUMO_ACCESS_KEY = os.environ.get('SUMO_ACCESS_KEY')
SUMO_URL = os.environ.get('SUMO_URL')
INTERVAL_SECONDS = int(os.environ.get('INTERVAL_SECONDS', 3600))
DOMAIN = os.environ.get('DOMAIN')

inventory_file = ".inventory.yaml"

r = run(["envsubst < vars.yaml.envsubst > vars.yaml"],
        shell=True, stdout=PIPE, stderr=PIPE)


def get_stopped_collectors(domain):
    r = requests.get(SUMO_URL,
                     auth=HTTPBasicAuth(SUMO_ACCESS_ID, SUMO_ACCESS_KEY))
    hosts = []
    if r.status_code != 200:
        print("ERROR: API 401: Invalid auth? Check user/pass/token.")
        return 1
    items = r.json()['collectors']
    for item in items:
        host = item['name'].replace('_events', '')
        host = f"{host}.{domain}"
        alive = item['alive']

        if test_is_valid_host_or_ipaddr(host) != 0:
            continue
        if alive is not False:
            continue
        try:
            os = ""
            os = item['osName']
        except Exception as e:
            print(e)
            continue
        if "windows" in os.lower():
            print(host)
            logging.info(host)
            hosts.append(host)
        elif "linux" in os.lower():
            pass
        else:
            pass
            # print(f"{host} appears to be down or os is not unsupported.")
            continue
    create_ansible_inventory(hosts)


def create_ansible_inventory(hosts):
    txt = ("all:\n"
           "  hosts:\n")
    for host in hosts:
        txt = txt + f"    {host}:\n"
    with open(inventory_file, 'w') as f:
        f.write(txt)


def test_is_valid_host_or_ipaddr(host):
    try:
        ipaddress.ip_address(host)
        return 0
    except Exception as e:
        print(e)
        pass
    try:
        socket.gethostbyname(host)
        return 0
    except Exception as e:
        print(e)
        # print(f"E: {host} is not valid ip address or can't be resolved!")
        return 1


def main():
    while True:
        get_stopped_collectors(DOMAIN)
        c = f"ansible-playbook -i {inventory_file} playbookSumoCollector.yaml"
        r = run([c],
                shell=True, capture_output=True)
        print("E: ==========================================")
        err = r.stderr.decode().replace("\n", "")
        print(err)
        print("I: ==========================================")
        out = r.stdout.decode().replace("\n", "")
        print(out)
        print(f"Waiting {INTERVAL_SECONDS} seconds for next loop.")
        time.sleep(INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
