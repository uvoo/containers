# syntax=docker/dockerfile:1
FROM python:slim-buster

WORKDIR /app

# SHELL ["/bin/bash", "-c"]
COPY requirements.txt requirements.txt
RUN python3 -m venv venv
RUN . venv/bin/activate
RUN pip3 install -r requirements.txt

# COPY . .
COPY app.py .
COPY downloads/ downloads 
COPY wsgi.py .
COPY main .
COPY README.md .
COPY  zabbix_agent2.conf.jinja .
COPY installZabbixAgent.jinja .
# COPY install-zabbix.ps1.jinja .
# COPY install-zabbix.sh.jinja .
# this last might not be needed
COPY zabbix_agent.conf.jinja .

RUN groupadd -r app -g 1000 && useradd -u 1000 -r -g app -m -d /app -s /sbin/nologin -c "App user" app && \
  chmod 755 /app

USER app

CMD [ "python3", "app.py"]

# RUN chmod +x main
# ENTRYPOINT [ ./main ]
