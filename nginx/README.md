# NGINX OpenSource + Additional Modules

This NGINX currently based on Debian bitnami nginx in order use with helm.

We are using dynamic modules so we don't have to recompile nginx binary.

Read about dynamic modules https://docs.nginx.com/nginx/admin-guide/dynamic-modules/dynamic-modules/

# Dynamic vs Static NGINX Modules via Dockerfiles
- static https://github.com/gabihodoroaga/nginx-ntlm-module/blob/master/docker/alpine/static/Dockerfile 
- dynamic https://github.com/gabihodoroaga/nginx-ntlm-module/blob/master/docker/alpine/dynamic/Dockerfile

## Includes additional support for
- ntlm

## Based on
- https://github.com/bitnami/containers/tree/main/bitnami/nginx
- https://github.com/gabihodoroaga/nginx-ntlm-module/tree/master/docker/alpine/dynamic
- https://github.com/gabihodoroaga/nginx-ntlm-module/blob/master/docker/alpine/static
