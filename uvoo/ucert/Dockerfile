FROM ubuntu:22.04

ENV GOOSE_VERSION=3.15.1
ENV CFSSL_VERSION=1.6.4
ENV GO_VERSION=1.21.3
ENV CERTSTRAP_VERSION=1.3.0
ENV ADMIN_USERNAME=certadmin

ENV APP_DIR=/app
ENV ADMIN_DIR=/home/${ADMIN_USERNAME}
WORKDIR ${APP_DIR}

# SET TIMEZONE
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# ADD USER FOR SSH LOGIN
RUN useradd -m -d ${ADMIN_DIR} -s /bin/bash -u 1001 ${ADMIN_USERNAME}

# COPY FILES 
COPY README.md .
COPY examples/ ./examples/
COPY cfssl-ca/ ./cfssl-ca/
COPY cfssl-ca/init-cfssl-ca.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-cfssl-ca.sh
COPY openssl-ca/ ./openssl-ca/
COPY openssl-ca/init-openssl-ca.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-openssl-ca.sh
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
    git \
    gnupg2 \
    libltdl-dev \
    make \
    nano \
    openssh-server \
    openssl \
    sudo \
    vim

RUN apt-get clean

# INSTALL CERTSTRAP
RUN curl -LO "https://github.com/square/certstrap/releases/download/v${CERTSTRAP_VERSION}/certstrap-linux-amd64"
RUN chmod +x certstrap-linux-amd64
RUN mv certstrap-linux-amd64 /usr/local/bin/certstrap
RUN certstrap -v

# SSHD Prep
RUN mkdir /var/run/sshd
RUN service ssh stop

### CFSSL

# GO
RUN curl -LO https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz
RUN sudo sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
ENV PATH="${PATH}:/usr/local/go/bin"

# GOOSE
RUN curl -LO https://github.com/pressly/goose/releases/download/v${GOOSE_VERSION}/goose_linux_x86_64
RUN sudo chown root:root goose_linux_x86_64
RUN sudo chmod 755 goose_linux_x86_64
RUN sudo mv goose_linux_x86_64 /usr/local/bin/goose

# CFSSL
RUN mkdir -p src
RUN cd src && \
  git clone --depth 1 --branch v${CFSSL_VERSION} https://github.com/cloudflare/cfssl.git && \
  cd cfssl && \
  make && \
  sudo cp bin/* /usr/local/bin/
RUN mkdir $ADMIN_DIR/cfssl-ca && cp src/cfssl/certdb/sqlite/migrations/*.sql $ADMIN_DIR/cfssl-ca/


EXPOSE 22

# USER root
# STOPSIGNAL SIGUSR1

CMD ["bash", "-euc", "${APP_DIR}/main.sh"]
