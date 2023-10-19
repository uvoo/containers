FROM ubuntu:22.04

ENV CERTSTRAP_VERSION=1.3.0
ENV APP_USERNAME=app

ENV APPDIR=/${APP_USERNAME}
# ENV APP_USERDIR=/${HOMEDIR}/${APP_USERNAME}
# ENV APP_USERDIR=${APPDIR}/${APP_USERNAME}
ENV APP_USERDIR=/home/${APP_USERNAME}
WORKDIR ${APPDIR}

# SET TIMEZONE
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# ADD USER FOR SSH LOGIN
# RUN useradd -ms /bin/bash
RUN useradd -m -d ${APP_USERDIR} -s /bin/bash -u 1001 ${APP_USERNAME}
# USER ${APP_USERNAME}
# # RUN mkdir -p ${APP_USERDIR}/.ssh
# RUN mkdir -p ~/.ssh
# RUN chmod 700 ~/.ssh
# # RUN touch ${APP_USERDIR}/.ssh/authorized_keys
# RUN touch ~/.ssh/authorized_keys
# RUN chmod 600 ~/.ssh/authorized_keys
# USER root

# RUN touch ${APP_USERDIR}/.ssh/authorized_keys
# RUN chown -R ${APP_USERNAME}:${APP_USERNAME} ${APP_USERDIR}/.ssh
# RUN chown ${APP_USERNAME}:${APP_USERNAME} ${APP_USERDIR}/.ssh

COPY README.md .
COPY example1.sh .
COPY example2.sh .
COPY example3.sh .
COPY example-init-ca-nopass.sh .
COPY main.sh .
RUN chmod +x main.sh
COPY init-ca.sh .
RUN chmod +x init-ca.sh
RUN cp init-ca.sh $APP_USERDIR/
RUN chown $APP_USERNAME $APP_USERDIR/init-ca.sh

RUN set -eux && \
    apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
    ca-certificates \
    curl \
    nano \
    openssh-server \
    openssl \
    sudo \
    vim

RUN apt-get clean

# CERTSTRAP
RUN curl -LO "https://github.com/square/certstrap/releases/download/v${CERTSTRAP_VERSION}/certstrap-linux-amd64"
RUN chmod +x certstrap-linux-amd64
RUN mv certstrap-linux-amd64 /usr/local/bin/certstrap
RUN certstrap -v

# SSH
RUN mkdir /var/run/sshd
RUN service ssh stop
# COPY ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
# RUN chmod 600 /etc/ssh/ssh_host_rsa_key
# COPY ssh_host_rsa_key.pub /etc/ssh/ssh_host_rsa_key.pub
# RUN chmod 644 /etc/ssh/ssh_host_rsa_key.pub
# COPY ssh_host_ecdsa_key /etc/ssh/ssh_host_ecdsa_key
# RUN chmod 600 /etc/ssh/ssh_host_ecdsa_key
# COPY ssh_host_ecdsa_key.pub /etc/ssh/ssh_host_ecdsa_key.pub
# RUN chmod 644 /etc/ssh/ssh_host_ecdsa_key.pub
# COPY ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
# RUN chmod 600 /etc/ssh/ssh_host_ed25519_key
# COPY ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
# RUN chmod 644 /etc/ssh/ssh_host_ed25519_key.pub

# GO
# RUN curl -LO https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz
# RUN sudo sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
# ENV PATH="${PATH}:/usr/local/go/bin"

EXPOSE 22

# USER root
# STOPSIGNAL SIGUSR1

CMD ["bash", "-euc", "${APPDIR}/main.sh"]
