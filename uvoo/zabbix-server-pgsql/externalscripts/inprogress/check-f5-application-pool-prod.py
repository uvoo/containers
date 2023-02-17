import argparse, base64, json, os, sys, traceback
from requests import Session, packages, exceptions
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry
from urllib3.exceptions import InsecureRequestWarning, MaxRetryError
from urllib3.util import Timeout
from math import ceil


class F5Session():
    def __init__(self, baseUrl: str):

        self.authConnectTimeout = 30 
        self.authReadTimeout = 120
        self.baseUrl = baseUrl
        self.memberStatusConnectTimeout = 30
        self.memberStatusReadTimeout = 120
        self.usern = env_var_decode(os.environ.get('F5_API_CUENV_PROD'))
        self.passw = env_var_decode(os.environ.get('F5_API_CPENV_PROD'))

        retryStrategy = Retry(
            total=15,
            connect=10,
            status_forcelist=[400, 401, 403, 429, 500, 502, 503, 504],
            method_whitelist=False,
            backoff_factor=.1,
            raise_on_status=True
        )

        adapter = HTTPAdapter(max_retries=retryStrategy)
        session = Session()
        session.mount("https://", adapter, )

        packages.urllib3.disable_warnings(category=InsecureRequestWarning) #Disables SSL Warnings :(
        self.session = session
        self.token = None

    def authenticate(self, usern=None, passw=None):
        f5session = self.session
        loginReference = "tmos"
        
        if usern == None or passw == None:
            usern = self.usern
            passw = self.passw

        payload = {
            "username": usern,
            "password": passw,
            "loginProviderName": loginReference
        }

        timeout = Timeout(connect=self.authConnectTimeout, read=self.authReadTimeout)

        try:
            response = f5session.post(f"https://{self.baseUrl}/mgmt/shared/authn/login", json=payload, verify=False, timeout=timeout)
            response = json.loads(response.text)
            token = response['token']['token']

            f5session.headers = {
                "Content-Type": "application/json",
                "X-F5-Auth-Token": token
            }

            self.token = response['token']['token']
        
        except exceptions.RetryError as e:
            self.token = None
            exceptiondata = traceback.format_exc().splitlines()
            print(exceptiondata[-1])

        except exceptions.Timeout as e:
            self.token = None
            exceptiondata = traceback.format_exc().splitlines()
            print(exceptiondata[-1])      

    def get_pool_members(self, poolPartition: str, poolName: str):
        if None != self.token:
            f5session = self.session
            timeout = Timeout(connect=self.memberStatusConnectTimeout, read=self.memberStatusReadTimeout)
            poolPath = f"https://{self.baseUrl}/mgmt/tm/ltm/pool/~{poolPartition}~{poolName}/members"
            response = f5session.get(poolPath, verify=False, timeout=timeout)
            response = json.loads(response.text)
            return response
    def delete_f5_token(self):
        f5session = self.session
        f5session.headers = {
            "X-F5-Auth-Token": self.token
        }
        uri = f"https://{self.baseUrl}//mgmt/shared/authz/tokens/{self.token}"
        f5session.delete(uri)

def env_var_decode(v: str):
    env = v.ljust(ceil(len(v) / 4) * 4, '=')
    base64_bytes = env.encode('utf-8')
    env_bytes = base64.b64decode(base64_bytes)
    envVar = env_bytes.decode('utf-8')
    return envVar

def get_f5_data (args):
    f5session = F5Session(args.f5target)
    f5session.authenticate()
    f5data = f5session.get_pool_members(args.f5part, args.f5pool)
    f5session.delete_f5_token()
    f5session.session.close()
    return f5data

def determine_pool_state (f5data=None):
    if None != f5data:
        downCount = [node["state"] for node in f5data["items"] if node["state"].lower() != "up" and node["state"].lower() != "fqdn-up"]
        downCount = len(downCount)

        if downCount >= int(args.downCritCount):
            message = "CRITICAL"
            state = 2
        else:
            message = "OK"
            state = 0

        output = f"{message}, F5 loadbalancer: {args.f5target}\r\n\r\nPool: {args.f5pool}\r\n\t"
        for node in f5data["items"]:
            output += (f"Node: {node['name']}\r\n\t  ")
            output += (f"  State: {node['state'].upper()}\r\n\t  ")
            output += (f"  Address: {node['address']}\r\n\t")
    else:
        output = None
        state = 3

    print(output)
    return(state)

def execute_check (args):
    f5data = get_f5_data(args)
    state = determine_pool_state(f5data)
    return state

    
if __name__ == "__main__":

    cinput = argparse.ArgumentParser(prog="f5check", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    cinput.add_argument("-t", "--f5target",
                        required=True,
                        default=None,
                        help="String: The FQDN for the target F5 load balancer.")
    cinput.add_argument("-p", "--f5pool",
                        required=True,
                        default=None,
                        help="String: The name of the target F5 Application Pool")
    cinput.add_argument("-l", "--f5part",
                        required=True,
                        default=None,
                        help="String: The name of the partiton where the target F5 Application Pool is located.")
    cinput.add_argument("-c", "--downCritCount",
                        required=True,
                        default=1,
                        help="INT: The acceptable number of members in the target F5 Application pool allowed to be in a Down state. Down Member Count => (-c/--downCritCount) will result in a Critical state.")

    args = cinput.parse_args()
    state = execute_check(args)
    sys.exit(state)
