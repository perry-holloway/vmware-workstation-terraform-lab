#!/usr/bin/env bash
set -euo pipefail

: "${PROMETHEUS_IMAGE:?PROMETHEUS_IMAGE is required}"
: "${NODE_EXPORTER_IMAGE:?NODE_EXPORTER_IMAGE is required}"
: "${HOST_NAME:?HOST_NAME is required}"

hostnamectl set-hostname "${HOST_NAME}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
"${SCRIPT_DIR}/install-docker.sh"

install -d -m 0755 /opt/monitoring/standalone/prometheus
install -m 0644 "${SCRIPT_DIR}/prometheus.yml" /opt/monitoring/standalone/prometheus/prometheus.yml

cat >/opt/monitoring/standalone/compose.yml <<EOF
services:
  prometheus:
    image: ${PROMETHEUS_IMAGE}
    container_name: prometheus
    restart: unless-stopped
    network_mode: host
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time=15d
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus

  node-exporter:
    image: ${NODE_EXPORTER_IMAGE}
    container_name: node-exporter
    restart: unless-stopped
    network_mode: host
    pid: host
    command:
      - --path.rootfs=/host
    volumes:
      - /:/host:ro,rslave

volumes:
  prometheus-data:
EOF

docker compose -f /opt/monitoring/standalone/compose.yml pull
docker compose -f /opt/monitoring/standalone/compose.yml up -d --remove-orphans
