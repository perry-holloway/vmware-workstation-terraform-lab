#!/usr/bin/env bash
set -euo pipefail

: "${SSH_USER:?SSH_USER is required}"
: "${CHART_VERSION:?CHART_VERSION is required}"
: "${HOST_NAME:?HOST_NAME is required}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
hostnamectl set-hostname "${HOST_NAME}"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl

if ! command -v k3s >/dev/null 2>&1; then
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik --write-kubeconfig-mode 644" sh -
fi

systemctl enable --now k3s
until k3s kubectl get node >/dev/null 2>&1; do
  sleep 5
done

if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

install -d -m 0755 "/home/${SSH_USER}/.kube"
cp /etc/rancher/k3s/k3s.yaml "/home/${SSH_USER}/.kube/config"
chown -R "${SSH_USER}:${SSH_USER}" "/home/${SSH_USER}/.kube"

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --version "${CHART_VERSION}" \
  --values "${SCRIPT_DIR}/kube-prometheus-values.yml" \
  --wait \
  --timeout 15m
