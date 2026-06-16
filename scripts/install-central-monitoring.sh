#!/usr/bin/env bash
set -euo pipefail

: "${PROMETHEUS_IMAGE:?PROMETHEUS_IMAGE is required}"
: "${NODE_EXPORTER_IMAGE:?NODE_EXPORTER_IMAGE is required}"
: "${GRAFANA_IMAGE:?GRAFANA_IMAGE is required}"
: "${GRAFANA_ADMIN_PASSWORD_B64:?GRAFANA_ADMIN_PASSWORD_B64 is required}"
: "${HOST_NAME:?HOST_NAME is required}"

GRAFANA_ADMIN_PASSWORD=$(printf '%s' "${GRAFANA_ADMIN_PASSWORD_B64}" | base64 -d)
hostnamectl set-hostname "${HOST_NAME}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
"${SCRIPT_DIR}/install-docker.sh"

install -d -m 0755 \
  /opt/monitoring/central/prometheus \
  /opt/monitoring/central/prometheus/rules \
  /opt/monitoring/central/grafana/provisioning/datasources \
  /opt/monitoring/central/grafana/provisioning/dashboards \
  /opt/monitoring/central/grafana/dashboards

install -m 0644 "${SCRIPT_DIR}/prometheus.yml" /opt/monitoring/central/prometheus/prometheus.yml
install -m 0644 "${SCRIPT_DIR}/alerts.yml" /opt/monitoring/central/prometheus/rules/alerts.yml
cp -a "${SCRIPT_DIR}/grafana/provisioning/." /opt/monitoring/central/grafana/provisioning/
cp -a "${SCRIPT_DIR}/grafana/dashboards/." /opt/monitoring/central/grafana/dashboards/
printf '%s' "${GRAFANA_ADMIN_PASSWORD}" >/opt/monitoring/central/grafana-admin-password
chmod 600 /opt/monitoring/central/grafana-admin-password

cat >/opt/monitoring/central/compose.yml <<EOF
services:
  prometheus:
    image: ${PROMETHEUS_IMAGE}
    container_name: central-prometheus
    restart: unless-stopped
    network_mode: host
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time=30d
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/rules:/etc/prometheus/rules:ro
      - prometheus-data:/prometheus

  grafana:
    image: ${GRAFANA_IMAGE}
    container_name: grafana
    restart: unless-stopped
    network_mode: host
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD__FILE: /run/secrets/grafana_admin_password
      GF_USERS_ALLOW_SIGN_UP: "false"
    secrets:
      - grafana_admin_password
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
      - grafana-data:/var/lib/grafana

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
  grafana-data:

secrets:
  grafana_admin_password:
    file: ./grafana-admin-password
EOF

docker compose -f /opt/monitoring/central/compose.yml pull
docker compose -f /opt/monitoring/central/compose.yml up -d --remove-orphans
