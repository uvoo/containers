```
RUN set -eux && \
    apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
    ca-certificates \
    curl \
    gettext-base \
    git \
    libltdl-dev \
    make \
    nano \
    nginx \
    openssh-server \
    openssl \
    postgresql-14 \
    rsyslog \
    iproute2 \
    snoopy \
    supervisor \
    sudo \
    vim
RUN apt-get clean
```
