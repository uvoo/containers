FROM ubuntu:22.04

ARG USERNAME=app
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create the user

ENV GOOSE_VERSION=3.15.1
ENV CFSSL_VERSION=1.6.5
ENV GO_VERSION=1.21.3

ENV APP_DIR=/home/app
WORKDIR ${APP_DIR}

ENV CGO_ENABLED=1
# SET TIMEZONE
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# ADD USER FOR SSH LOGIN
# RUN useradd -m -d ${ADMIN_DIR} -s /bin/bash -u 1001 ${ADMIN_USERNAME}

# RUN adduser -S -D -H -u 1001 -h /app -s /sbin/nologin -G app -g app app
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && chown -R $USER_UID:$USER_GID /home/$USERNAME
    # && chown -R $USER_UID:$USER_GID /$USERNAME

# COPY FILES 
COPY README.md .
# COPY init-cfssl-ca.sh /usr/local/bin/
# RUN chmod +x /usr/local/bin/init-cfssl-ca.sh
COPY main.sh .
RUN chmod +x main.sh
COPY init-cfssl-ca.sh .
RUN chmod +x init-cfssl-ca.sh
# COPY init-ca.sh .
# RUN chmod +x init-ca.sh
# RUN cp init-ca.sh $ADMIN_DIR/
# RUN chown $ADMIN_USERNAME $ADMIN_DIR/init-ca.sh

    # gcc \
RUN set -eux && \
    apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
    ca-certificates \
    curl \
    git \
    gnupg2 \
    libltdl-dev \
    libc6-dev \
    sqlite3 \
    golang-github-mattn-go-sqlite3-dev \
    make \
    gcc \
    nano \
    openssh-server \
    openssl \
    sudo \
    vim

RUN apt-get clean

### CFSSL
# GO
RUN curl -LO https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz
RUN sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
RUN sudo rm go${GO_VERSION}.linux-amd64.tar.gz
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
# RUN mkdir $APP_DIR/cfssl-ca && cp src/cfssl/certdb/sqlite/migrations/*.sql $AAPP_DIR/cfssl-ca/
# RUN cp src/cfssl/certdb/sqlite/migrations/*.sql ./cfssl-ca/ 
RUN mkdir -p migrations
RUN mv src/cfssl/certdb/sqlite/migrations ./migrations/sqlite3
RUN mv src/cfssl/certdb/pg/migrations ./migrations/postgres
RUN rm -rf src
# RUN chown -R app:app ${APP_DIR}:${APP_DIR}
# RUN chown -R ${APP_DIR}:${APP_DIR} ${APP_DIR}
# RUN chown -R $USER_UID:$USER_GID /$USERNAME
RUN chown -R $USER_UID:$USER_GID /home/$USERNAME


EXPOSE 3000


USER 1000
# USER root
# STOPSIGNAL SIGUSR1

# CMD ["bash", "-euc", "${APP_DIR}/main.sh"]
CMD ["bash", "-euc", "${APP_DIR}/main.sh"]
