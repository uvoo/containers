# To install and run in bash

Install ansible
```
apt install ansible
```
use dnf or yum install ansible if RHEL based

Download
```
git clone https://github.com/uvoo/docker-sumo-collector-healer.git
cd docker-sumo-collector-healer 
```

Copy example .env
```
cp .env.example .env
```

Then edit .env and set your personal preferences
```
nano .env
```

Set environment variables in bash
```
. .env
```

Run service which loops depending on INTERVAL
```
python3 app.py 
```

Single Example with .env set to your environment
```
. .env
envsubst < vars.yaml.envsubst > vars.yaml
ansible-playbook -i myhostoripaddr, playbookSumoCollector.yaml
```

# Python Virtual Environment
Using Python3 venv
```
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements.txt
python3 -u app.py
```

Exit virtual environment
```
deactivate
```
