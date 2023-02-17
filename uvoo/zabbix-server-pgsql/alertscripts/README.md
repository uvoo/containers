# Custom Alert Scripts

https://www.zabbix.com/documentation/current/manual/config/notifications/media/script

## Nexmo/Vonage sms and voice scripts
- Admin https://dashboard.nexmo.com/

```
pip install -r requirements.txt
```

.env
```
export NEXMO_SECRET_PEM="""\
-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----"""

export NEXMO_APPLICATION_ID=""
export NEXMO_PHONE_FROM="1801xxxxxx"
export NEXMO_SMS_KEY=''
export NEXMO_SMS_SECRET=''
```

Export env vars
```
. .env
```
