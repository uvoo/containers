https://github.com/psi-4ward/docker-powerdns mysql auto

https://github.com/PowerDNS/pdns/blob/master/Dockerfile-auth

https://github.com/svinther/docker-powerdns-postgres

https://dmachard.github.io/posts/0010-powerdns-dnsdist-docker/

https://doc.powerdns.com/authoritative/settings.html

https://doc.powerdns.com/authoritative/manpages/pdnsutil.1.html

# Terraform

- https://registry.terraform.io/providers/pan-net/powerdns/latest/docs/resources/record#example-usage


# Getting Started with Docker

```
cp example.env .env
cp example.env.secrets .env.secrets
```

Make your variable changes in .env and .env.secrets then run

```
. .env
. .env.secrets
```

Build and Run with run-docker.sh script

```
./run-docker.sh
```
