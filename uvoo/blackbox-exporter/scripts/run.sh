docker rm blackbox-exporter -f || true
docker run -p 19115:9115 --name blackbox-exporter-busk blackbox-exporter
