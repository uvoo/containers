FROM ubuntu:22.04

ENV CERTSTRAP_VERSION=1.3.0
ENV ADMIN_USERNAME=certadmin

ENV APP_DIR=/app
# ENV ADMIN_DIR=/${HOMEDIR}/${ADMIN_USERNAME}
# ENV ADMIN_DIR=${APP_DIR}/${ADMIN_USERNAME}
ENV ADMIN_DIR=/home/${ADMIN_USERNAME}
WORKDIR ${APP_DIR}

# SET TIMEZONE
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# ADD USER FOR SSH LOGIN
# RUN useradd -ms /bin/bash
RUN useradd -m -d ${ADMIN_DIR} -s /bin/bash -u 1001 ${ADMIN_USERNAME}
# USER ${ADMIN_USERNAME}
# # RUN mkdir -p ${ADMIN_DIR}/.ssh
# RUN mkdir -p ~/.ssh
# RUN chmod 700 ~/.ssh
# # RUN touch ${ADMIN_DIR}/.ssh/authorized_keys
# RUN touch ~/.ssh/authorized_keys
# RUN chmod 600 ~/.ssh/authorized_keys
# USER root

# RUN touch ${ADMIN_DIR}/.ssh/authorized_keys
# RUN chown -R ${ADMIN_USERNAME}:${ADMIN_USERNAME} ${ADMIN_DIR}/.ssh
# RUN chown ${ADMIN_USERNAME}:${ADMIN_USERNAME} ${ADMIN_DIR}/.ssh

COPY README.md .
COPY examples .
COPY main.sh .
RUN chmod +x main.sh
COPY init-ca.sh .
RUN chmod +x init-ca.sh
RUN cp init-ca.sh $ADMIN_DIR/
RUN chown $ADMIN_USERNAME $ADMIN_DIR/init-ca.sh

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

CMD ["bash", "-euc", "${APP_DIR}/main.sh"]
