# Uvoo containers
uvoo docker container builds

The docker build/push only runs when a changed is detected in container folder between last two commits. 

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
