FROM ubuntu:noble
RUN set -eux && \
    apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
    postfix \
    sudo \
    opendkim \
    opendkim-tools \
    nano \
    vim \
    openssl \
    dnsutils \
    python3-pip \
    python3-venv \
    libssl-dev \
    libffi-dev \
    python3-dev \
    iproute2 \
    libsasl2-modules \
    supervisor \
    rsyslog \
    ca-certificates \
    sasl2-bin \
    iputils-ping
        # build-essential \


# Python
# ENV VIRTUAL_ENV=/opt/venv
# ENV PATH="$VIRTUAL_ENV/bin:$PATH"
# RUN python3 -m venv $VIRTUAL_ENV
# RUN pip install --upgrade pip && \
#     pip --no-cache-dir install envtpl

# Notes
## RUN python3 -m pip install --break-system-packages envtpl
# COPY requirements.txt .
## RUN pip install -r requirements.txt
## RUN python3 -m pip cache remove *


RUN apt-get clean && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# COPY ./main.cf.tpl /etc/postfix/
# COPY ./master.cf.tpl /etc/postfix/
COPY ./check-policy-service.py /etc/
COPY ./opendkim.conf /etc/
COPY ./supervisord.conf /etc/supervisord.conf
COPY ./rsyslog.conf /etc/rsyslog.conf

EXPOSE 8587

COPY ./docker-entrypoint.sh /app/ 

RUN sed -i 's/^smtp      inet.*/8587      inet  n       -       y       -       -       smtpd/g' /etc/postfix/master.cf
# RUN echo "submission inet n       -       y       -       -       smtpd" >> /etc/postfix/master.cf
# RUN useradd -ms /bin/bash postfixuser
# USER postfixuser
# USER root

STOPSIGNAL SIGUSR1
ENTRYPOINT ["/app/docker-entrypoint.sh"]
