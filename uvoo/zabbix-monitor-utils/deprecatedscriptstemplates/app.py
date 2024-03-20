import ast
import os
from pathlib import Path
from secrets import token_hex
import shutil
import sys
import urllib3
import uuid

from flask import (Flask, request, abort, jsonify,
                   Response, send_from_directory, current_app)
from jinja2 import Template, FileSystemLoader, Environment
from pyzabbix import ZabbixAPI, ZabbixAPIException


urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
homedir = str(Path.home())
app = Flask(__name__)


admin_token = os.environ.get('MONITOR_REGISTRATION_ADMIN_TOKEN')
token = os.environ.get('MONITOR_REGISTRATION_TOKEN')
username = os.environ.get('ZABBIX_USERNAME')
userpass = os.environ.get('ZABBIX_USERPASS')
ZABBIX_URL = os.environ.get('ZABBIX_URL')
ZABBIX_AGENT_SERVER = os.environ.get('ZABBIX_AGENT_SERVER')
ZABBIX_AGENT_SERVERACTIVE = os.environ.get('ZABBIX_AGENT_SERVERACTIVE')
AUTOREG_TLSPSKIDENTITY = os.environ.get(
    'AUTOREGISTRATION_TLSPSKIDENTITY',
    'autoregistration--c811d00e-1495-11ec-88fc-3fadeb64ed55')
AUTOREG_TLSPSKVALUE = os.environ.get(
    'AUTOREGISTRATION_TLSPSKVALUE',
    'b473ce5b17bc1d20e92adc0a3e3f2325674ab3bad3f06946b410347b73f13c79')
PROXYTOKEN = os.environ.get('PROXYTOKEN', "")
global DEFAULT_DOMAIN
global DEFAULT_OS
global DEFAULT_SHELL
DEFAULT_DOMAIN = os.environ.get('DEFAULT_DOMAIN')
DEFAULT_OS = os.environ.get('DEFAULT_OS', 'Linux')
DEFAULT_SHELL = os.environ.get('DEFAULT_SHELL', 'bash')

required_args = (DEFAULT_DOMAIN, DEFAULT_OS, DEFAULT_SHELL,
                 ZABBIX_AGENT_SERVER, ZABBIX_AGENT_SERVERACTIVE, ZABBIX_URL)
if any(i is None for i in required_args):
    msg = ("E: Missing at least one required environmental variable"
           "DEFAULT_DOMAIN, DEFAULT_OS, DEFAULT_SHELL,,"
           "ZABBIX_AGENT_SERVER, ZABBIX_AGENT_SERVERACTIVE, ZABBIX_URL")
    print(msg)
    sys.exit()

try:
    zapi = ZabbixAPI(ZABBIX_URL)
    zapi.session.verify = False
    api_auth_token = zapi.login(username, userpass)
    zapi.user.get(userids=-1)
except Exception as e:
    print(e)


def acl():
    if request.args.get("token") != token:
        abort(404, description="Resource not found")
        return


def acl_admin():
    if request.args.get("token") != admin_token:
        abort(404, description="Resource not found")
        return


class Host:
    def __init__(self, ip, hostname, hostgroups,
                 dns, os, pd_service_integration_key=""):
        self.dns = dns
        if isinstance(hostgroups, str):
            self.hostgroups = [hostgroups]
        else:
            self.hostgroups = hostgroups

        if len(pd_service_integration_key) > 1:
            self.hostgroups.append("PagerDuty")
        self.hostname = hostname
        self.ip = ip
        self.os = os
        self.server = ZABBIX_AGENT_SERVER
        self.serveractive = ZABBIX_AGENT_SERVERACTIVE
        self.hostname = self.hostname
        self.pd_service_integration_key = pd_service_integration_key
        self.tlsconnect = "psk"
        self.tlsaccept = "psk"
        self.tlspskidentity = f"{hostname}--" + str(uuid.uuid4())
        self.tlspskvalue = token_hex(32)  # openssl rand -hex 32
        self.hostuuid = self.tlspskidentity

    def add_to_zabbix(self):
        interface_list = [{
            "type": 1,
            "main": 1,
            "useip": 1,
            "ip": str(self.ip),
            "dns": self.dns,
            "port": "10050"
        }]

        groups = list()

        for g in self.hostgroups:
            groups.append({"groupid": str(get_hostgroup_id(g))})

        templateids = []
        if self.os == "windows":
            templateids.append(10683)  # set to your template id
        elif self.os == "linux":
            templateids.append(10396)  # set to your template id

        query = {
            'host': str(self.hostname),
            'groups': groups,
            'proxy_hostid': '0',
            'status': '0',
            'interfaces': interface_list,
            'tls_psk_identity': self.tlspskidentity,
            'tls_connect': 2,
            'tls_accept': 2,  # 4 is certificate
            'tls_psk': self.tlspskvalue,
            'inventory_mode': 1,
            'inventory': {
                'name': str(self.hostname),
                'alias': str(self.pd_service_integration_key)
            }
        }
        try:
            r = zapi.host.create(**query)
        except Exception as e:
            return e
        try:
            hostid = zapi.host.get(filter={'host': self.hostname},
                                   output=['hostids'])[0]['hostid']
            zapi.host.update({"hostid": hostid, "templates": templateids})
        except Exception as e:
            return e
        return r

    def get_os(self, os=None):
        if os:
            self.os = os
        elif "Windows" in self.user_agent:
            self.os = "windows"
        elif "Linux" in self.user_agent:
            self.os = "linux"
        else:
            self.os = "undetected"

    def create_install_files(self):
        if self.os == "windows":
            if request.args.get("usechoco"):
                with open('choco-install-cmd.txt', 'r') as f:
                    txt = " ".join(line.rstrip() for line in f.readlines())
                # /ENABLEREMOTECOMMANDS:1 ENABLEPATH:0
                return Response(txt, mimetype='text/plain')
            install_file = "install-zabbix.ps1.template"
            with app.open_resource(install_file) as f:
                txt = f.read()
            txt = txt.decode()
            txt = txt.replace("{{hostname}}", self.hostname)
            txt = txt.replace("{{tlspskidentity}}", self.tlspskidentity)
            txt = txt.replace("{{tlspskvalue}}", self.tlspskvalue)
            return Response(txt, mimetype='text/plain')
        elif self.os == "linux":
            tlspskfile = "/etc/zabbix/psk.key"
            install_file = "install-zabbix.sh.template"
            with app.open_resource(install_file) as f:
                txt = f.read()
            txt = txt.decode()
            txt = txt.replace("{{hostname}}", self.hostname)
            txt = txt.replace("{{dns}}", self.dns)
            txt = txt.replace("{{tlspskidentity}}", self.tlspskidentity)
            txt = txt.replace("{{tlspskfile}}", tlspskfile)
            txt = txt.replace("{{tlspskvalue}}", self.tlspskvalue)
            return Response(txt, mimetype='text/plain')
        elif self.os == "undetected":
            txt = "Undetected OS please use arg os=windows or os=linux"
            return Response(txt, mimetype='text/plain')
        else:
            txt = "Unsupported OS"
            return Response(txt, mimetype='text/plain')

    def remove_config_files(self):
        hostname = self.hostuuid.split("--")[0]
        if len(hostname) < 4:
            return
        agentDir = "/app/monitor-registration/agent"
        p = Path(agentDir).glob(f"{hostname}*")
        dirs = [x for x in p if x.is_dir()]
        for dir in dirs:
            shutil.rmtree(dir)

    def write_host_config_files(self):
        targs = {}
        targs['tlspskidentity'] = self.tlspskidentity
        targs['tlspskvalue'] = self.tlspskvalue
        targs['hostname'] = self.hostname
        targs['dns'] = self.dns
        targs['ZABBIX_URL'] = ZABBIX_URL
        targs['ZABBIX_AGENT_SERVERACTIVE'] = ZABBIX_AGENT_SERVERACTIVE
        targs['ZABBIX_AGENT_SERVER'] = ZABBIX_AGENT_SERVER
        targs['AUTOREG_TLSPSKIDENTITY'] = AUTOREG_TLSPSKIDENTITY

        targs['os'] = self.os
        templateLoader = FileSystemLoader(searchpath="./")
        templateEnv = Environment(loader=templateLoader)
        if self.os == "windows":
            install_template_file = "install-zabbix.ps1.jinja"
        elif self.os == "linux":
            tlspskfile = "/etc/zabbix/psk.key"
            targs['tlspskfile'] = tlspskfile
            install_template_file = "install-zabbix.sh.jinja"
        else:
            print("Unsupported os")
            return
        config_template_file = "zabbix_agent2.conf.jinja"
        install_template = templateEnv.get_template(install_template_file)
        config_template = templateEnv.get_template(config_template_file)
        install_text = install_template.render(targs)
        hostdir = f"/app/monitor-registration/agent/{self.tlspskidentity}"
        Path(hostdir).mkdir(mode=0o700, parents=True, exist_ok=True)
        install_file = ("/app/monitor-registration/agent/"
                        f"{self.tlspskidentity}/installZabbixAgent")
        with open(install_file, 'w') as f:
            f.write(install_text)
        config_text = config_template.render(targs)
        agentconfig_file = ("/app/monitor-registration/agent/"
                            f"{self.tlspskidentity}/zabbix_agent2.conf")
        with open(agentconfig_file, 'w') as f:
            f.write(config_text)


def delete_host(hostname):
    f = {'host': hostname}
    hosts = zapi.host.get(filter=f, output=['hostids', 'host'])

    for host in hosts:
        zapi.host.delete(host['hostid'])
        break  # Allow only one, for now


def hostname_exists(hostname):
    f = {'host': hostname}
    hosts = zapi.host.get(filter=f, output=['hostids', 'host'])
    if len(hosts) == 0:
        return False
    else:
        return True

    # for host in hosts:
    #    zapi.host.delete(host['hostid'])
    #    return True
    #    break  # Allow only one, for now
    # return False


def get_choco_install_script():
    txt = ("Set-ExecutionPolicy Bypass -Scope Process -Force;"
           "[System.Net.ServicePointManager]::SecurityProtocol = "
           "[System.Net.ServicePointManager]::SecurityProtocol -bor 3072; "
           "iex ((New-Object System.Net.WebClient).DownloadString"
           "('https://chocolatey.org/install.ps1'))")
    return txt


def get_hostgroup_id(hostgroup):
    data = zapi.hostgroup.get(filter={'name': hostgroup})
    if data != []:
        hostgroupid = data[0]['groupid']
    else:
        raise Exception('Could not find hostgroupID for: ' + hostgroup)
    return str(hostgroupid)


def from_csv():
    csvfile = open('list.csv', 'r')
    for line in csvfile.readlines():
        if line.strip().startswith('#') or ',' not in line:
            continue
            line = line.strip().split(',')
        try:
            addhost(line[0], line[1], line[2].split(':'))
            print(f"Added {line[0]}")
        except Exception as e:
            print(f"Failed to add {line[0]}")
            print(e)


def create_agent_config_from_jinja(os_="windows"):
    hostname = request.args.get("hostname")
    hostInterfaceItem = request.args.get("dns")
    required_args = (hostname, hostInterfaceItem)
    if any(i is None for i in required_args):
        return "Missing required url args."
    targs = {}
    targs['ZABBIX_AGENT_SERVERACTIVE'] = os.getenv('ZABBIX_AGENT_SERVERACTIVE')
    targs['ZABBIX_AGENT_SERVER'] = os.getenv('ZABBIX_AGENT_SERVERACTIVE')
    targs['AUTOREG_TLSPSKIDENTITY'] = AUTOREG_TLSPSKIDENTITY
    targs['os'] = os_
    targs['hostname'] = hostname
    with open('zabbix_agent2.conf.jinja') as f_:
        template = Template(f_.read())
    txt = template.render(targs)
    print(txt)


@app.route('/addhost')
def addhost():
    acl()
    ipaddr = request.args.get("ipaddr")
    hostname = request.args.get("hostname")
    hostgroups = request.args.get("hostgroups")
    hostgroups = ast.literal_eval(hostgroups)
    # hostgroups = [hostgroups]
    dns = request.args.get("dns")
    os = request.args.get("os")
    pd_service_integration_key = request.args.get("pdServiceIntegrationKey")
    required_args = (ipaddr, hostname, hostgroups, dns, os)
    if any(i is None for i in required_args):
        return "Missing required url args."

    if request.args.get("delete"):
        delete_host(hostname)
    if request.args.get("force") == "true":
        delete_host(hostname)

    host = Host(ipaddr, hostname, hostgroups,
                dns, os, pd_service_integration_key)
    if hostname_exists(hostname):
        msg = (f"Hostname {hostname} already exists in Zabbix and must be"
               "deleted by admin before a new registration with the "
               "same hostname. You may use your registration identity "
               "string from previous registration.\n")
        msg += f"curl {ZABBIX_URL}/agentmanager/<regid>/zabbix_agent2.conf\n"
        msg += f"curl {ZABBIX_URL}/agentmanager/<regid>/installZabbixAgent"
        print(msg)
        return str(msg), 409
    # return "That's it"
    msg = {}
    msg['host'] = vars(host)
    r = host.add_to_zabbix()
    if not isinstance(r, ZabbixAPIException):
        # host.get_os(os)
        host.remove_config_files()
        host.write_host_config_files()
        host.user_agent = request.headers.get('User-Agent')
        # script_txt = host.get_script()
        # host.create_install_files()
        print(host.tlspskidentity)
        return str(host.tlspskidentity)
    else:
        msg['addhost_rsp'] = str(r)
        return jsonify(msg)


@app.route('/get-os')
def get_os():
    content = request.headers.get('User-Agent')
    return Response(content, mimetype='text/plain')


@app.route('/wagent/test/version')
def wagent_test_version():
    os = "windows"
    release = "v0.1.0"
    downloadURL = ("https://www.google.com/images/branding"
                   "/googlelogo/1x/googlelogo_color_272x92dp.png")
    name = "iutil"
    desc = "Latest version info for single file app executable binary."
    sha256 = "5776cd87617eacec3bc00ebcf530d1924026033eda852f706c1a675a98915826"
    r = {}
    r['desc'] = desc
    r['name'] = name
    r['release'] = release
    r['os'] = os
    r['SHA256'] = sha256
    r['downloadURL'] = downloadURL
    return jsonify(r)


@app.route('/agent/<path:name>')
def agentconfig_dir(name):
    # agent = os.path.join(current_app.root_path, 'agent')
    return send_from_directory('agent', name)


@app.route('/downloads/<path:name>', methods=['GET', 'POST'])
def download(name):
    downloads = os.path.join(current_app.root_path, 'downloads')
    return send_from_directory(downloads, name)


@app.route('/get/autoregistration/zabbix_agent2.conf', methods=['GET', 'POST'])
def get_agent2conf():
    HostMetadata = request.args.get('HostMetadata', default="", type=str)
    DOMAIN = request.args.get('domain', default=DEFAULT_DOMAIN, type=str)
    required_args = (HostMetadata)
    if any(i is None for i in required_args):
        return "Missing required url args: HostMetadata."
    if "Windows" in HostMetadata:
        os_ = "Windows"
        shell = "pwsh"
    elif "Linux" in HostMetadata:
        os_ = "Linux"
        shell = "bash"
    else:
        shell = DEFAULT_SHELL
        os_ = DEFAULT_OS
    targs = {}
    targs['ZABBIX_AGENT_SERVERACTIVE'] = ZABBIX_AGENT_SERVERACTIVE
    targs['ZABBIX_AGENT_SERVER'] = ZABBIX_AGENT_SERVER
    targs['AUTOREG_TLSPSKIDENTITY'] = AUTOREG_TLSPSKIDENTITY
    targs['os'] = os_
    targs['shell'] = shell
    targs['DOMAIN'] = DOMAIN
    targs['HostMetadata'] = HostMetadata
    with open('zabbix_agent2.conf.jinja') as f_:
        template = Template(f_.read())
    txt = template.render(targs)
    return Response(txt, mimetype='text/plain')


@app.route('/get/autoregistration/psk.key', methods=['GET', 'POST'])
def get_agentpsk():
    content = AUTOREG_TLSPSKVALUE
    return Response(content, mimetype='text/plain')


@app.route('/get/autoregistration/installZabbixAgent', methods=['GET', 'POST'])
def getInstallZabbixAgent():
    HostMetadata = request.args.get('HostMetadata', type=str)
    required_args = (HostMetadata)
    if any(i is None for i in required_args):
        return "Missing required url args: HostMetadata."
    if "Windows" in HostMetadata:
        os_ = "Windows"
        shell = "pwsh"
    elif "Linux" in HostMetadata:
        os_ = "Linux"
        shell = "bash"
    else:
        shell = DEFAULT_SHELL
        os_ = DEFAULT_OS
    targs = {}
    targs['ZABBIX_URL'] = ZABBIX_URL
    targs['PROXYTOKEN'] = PROXYTOKEN
    targs['shell'] = shell
    targs['os'] = os_
    targs['HostMetadata'] = HostMetadata
    with open('installZabbixAgent.jinja') as f_:
        template = Template(f_.read())
    txt = template.render(targs)
    return Response(txt, mimetype='text/plain')


@app.route('/get/health', methods=['GET', 'POST'])
def get_health():
    return Response("ok", mimetype='text/plain')


@app.route('/', methods=['GET'])
def get_root():
    return Response("ok", mimetype='text/plain')


if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=80)
