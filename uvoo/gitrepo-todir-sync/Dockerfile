FROM alpine:3.13.6

RUN apk add --no-cache bash git

COPY main.sh .
RUN chmod 0700 main.sh 

# ENTRYPOINT [ "bash", "-e", "main.sh" ]
ENTRYPOINT [ ./main.sh ]
