FROM ubuntu:focal
SHELL ["/bin/bash", "-c"]

WORKDIR /app

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
    gettext-base \
    python3 \
    python3-pip \
    python-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY main .
COPY config.yaml.envsubst .
COPY createFileFromJinjaUsingEnv.py .
COPY config.yaml.jinja .
# ADD https://raw.githubusercontent.com/zabbix-tooling/zabbix-ldap-sync/master/requirements.txt .
COPY Ldap.py .
COPY ldap2zabbix.py .
COPY Zabbix.py .
COPY requirements.txt .
RUN pip3 install -r requirements.txt
# ADD https://raw.githubusercontent.com/zabbix-tooling/zabbix-ldap-sync/master/zabbix-ldap-sync .

RUN chmod +x main
ENTRYPOINT [ "bash", "-e", "main" ]
# ENTRYPOINT [ "/app/main" ]
