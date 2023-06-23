#!/bin/bash
# https://serverfault.com/questions/760726/how-to-exit-all-supervisor-processes-if-one-exited-with-0-result

printf "READY\n";

while read line; do
  echo "Processing Event: $line" >&2;
  kill -3 $(cat "/tmp/supervisord.pid")
  # kill -3 $(cat "/var/run/supervisord.pid")
done < /dev/stdin
