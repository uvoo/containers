docker rm rsyslog
docker run --name rsyslog \
-e PERMITTED_PEERS=$PERMITTED_PEERS \
-e TARGET="$TARGET" \
-e SUMO_TOKEN="$SUMO_TOKEN" \
sumo-syslog-forwarder
