docker rm blackbox-exporter -f || true
# docker run --cap-drop ALL -p 19115:9115 --name blackbox-exporter blackbox-exporter
docker run --cap-drop ALL --cap-add NET_RAW  -p 19115:9115 -p 19116:9116 --name blackbox-exporter blackbox-exporter
