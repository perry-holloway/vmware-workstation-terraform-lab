#!/usr/bin/env bash
set -euo pipefail

TERRAFORM_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAktYvA26sOmhTnY4/E5zhkhXzun+0AoyAwYcaMFt1LW terraform-vmware-monitoring"
TERRAFORM_USER="${SUDO_USER:-$USER}"

if [[ "${TERRAFORM_USER}" == "root" ]]; then
  echo "Run this with sudo from the non-root account Terraform will use." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y open-vm-tools openssh-server cloud-init
systemctl enable --now open-vm-tools ssh

USER_HOME=$(getent passwd "${TERRAFORM_USER}" | cut -d: -f6)
install -d -m 0700 -o "${TERRAFORM_USER}" -g "${TERRAFORM_USER}" "${USER_HOME}/.ssh"
touch "${USER_HOME}/.ssh/authorized_keys"
grep -qxF "${TERRAFORM_PUBLIC_KEY}" "${USER_HOME}/.ssh/authorized_keys" || \
  printf '%s\n' "${TERRAFORM_PUBLIC_KEY}" >>"${USER_HOME}/.ssh/authorized_keys"
chown "${TERRAFORM_USER}:${TERRAFORM_USER}" "${USER_HOME}/.ssh/authorized_keys"
chmod 0600 "${USER_HOME}/.ssh/authorized_keys"

cat >/etc/sudoers.d/terraform-monitoring-lab <<EOF
${TERRAFORM_USER} ALL=(ALL) NOPASSWD:ALL
EOF
chmod 0440 /etc/sudoers.d/terraform-monitoring-lab
visudo -cf /etc/sudoers.d/terraform-monitoring-lab

cloud-init clean --logs --machine-id
echo "Template preparation complete. Powering off for cloning."
poweroff
