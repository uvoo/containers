```
with open(homedir + "/.zabbix/config.yaml", 'r') as f:
    try:
        config = yaml.safe_load(f)
    except yaml.YAMLError as e:
        print(e)
zapi:
  url: https://monitor.example.com
  username: ""
  userpass: ""
api:
  token: ""
  admin_token: ""
token = config['api']['token']
username = config['zapi']['username']
userpass = config['zapi']['userpass']
zapi = ZabbixAPI(config['zapi']['url'])
```
