# containers
uvoo docker container builds

Use Dockerfile.envsubst instead of Dockerfile if you have dynamic variables in your Dockerfile base on .env

## Adding a container to be built & pushed example

```
mkdir mycontainer
cd mycontainer
```

nano .env
```
export NGINX_VERSION=1.21.1
export NAME=nginx
export ORG=uvoo
export OS=debian
export RELEASE="0.1.0"
```

nano Dockerfile.envsubst 
```
FROM debian:bullseye
...
```

```
cd ../
git add mycontainer
```

git commit/push
