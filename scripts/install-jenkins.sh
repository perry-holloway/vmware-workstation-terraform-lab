#!/usr/bin/env bash
set -euo pipefail

: "${JENKINS_IMAGE:?JENKINS_IMAGE is required}"
: "${NODE_EXPORTER_IMAGE:?NODE_EXPORTER_IMAGE is required}"
: "${HOST_NAME:?HOST_NAME is required}"

hostnamectl set-hostname "${HOST_NAME}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
"${SCRIPT_DIR}/install-docker.sh"

install -d -m 0755 /opt/monitoring/jenkins

cat >/opt/monitoring/jenkins/compose.yml <<EOF
services:
  jenkins:
    image: ${JENKINS_IMAGE}
    container_name: jenkins
    restart: unless-stopped
    network_mode: host
    environment:
      JAVA_OPTS: "-Djenkins.install.runSetupWizard=true"
    volumes:
      - jenkins-home:/var/jenkins_home

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
  jenkins-home:
EOF

docker compose -f /opt/monitoring/jenkins/compose.yml pull
docker compose -f /opt/monitoring/jenkins/compose.yml up -d --remove-orphans
