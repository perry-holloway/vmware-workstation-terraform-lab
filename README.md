# VMware Workstation Pro Monitoring Lab

This project provisions a four-VM monitoring lab over SSH using Terraform.

## Architecture

```text
Prometheus VM (2 CPU / 4 GB)
  - Docker
  - Prometheus :9090
  - Node Exporter :9100

Kubernetes VM (2 CPU / 8 GB)
  - K3s
  - kube-prometheus-stack
  - Kubernetes Prometheus :30090
  - kube-state-metrics
  - Node Exporter :9100

Grafana VM (2 CPU / 4 GB)
  - Docker
  - Central Prometheus :9090
  - Grafana :3000
  - Node Exporter :9100
  - Scrapes all lab VMs
  - Federates selected Kubernetes metrics
  - Connects directly to Kubernetes Prometheus

Jenkins VM (2 CPU / 4 GB)
  - Docker
  - Jenkins LTS :8080
  - Node Exporter :9100
```

Grafana receives two provisioned data sources:

- **Central Prometheus:** host metrics from all four VMs and federated Kubernetes metrics.
- **Kubernetes Prometheus:** complete Kubernetes metrics collected by the Prometheus Operator stack.

Two starter dashboards are provisioned automatically:

- `VM Infrastructure Overview`
- `Kubernetes Overview`

Central Prometheus also loads starter alert rules for high CPU, memory, disk usage, node exporter availability, and basic Kubernetes health.

## VMware Workstation Integration

This edition targets VMware Workstation Pro 26 on Windows and uses its local automation tools:

- `vmrun -T ws` to clone, start, list, and inspect guests
- VMX configuration for CPU and RAM
- Operating-system configuration over SSH
- Docker, K3s, Helm, Prometheus, Grafana, Jenkins, Node Exporter, data sources, and dashboards

Workstation still does not have a first-party Terraform provider. Terraform invokes the installed Workstation CLI locally, then provisions the guests over SSH. A helper script can clone a prepared Ubuntu template into all four role VMs.

## 1. Prepare an Ubuntu Template

Create one Ubuntu Server template VM in Workstation Pro. Ubuntu 24.04 LTS or 26.04 LTS can be used. Give the template at least a 50 GB thin-provisioned disk because the Kubernetes clone needs that capacity.

This project includes a helper that creates a completely new blank template VM from the local Ubuntu ISO and does not reuse any existing VM:

```powershell
cd C:\Path\To\vmware-workstation-terraform-lab

PowerShell -NoProfile -ExecutionPolicy Bypass -File .\scripts\New-UbuntuTemplateVM.ps1 `
  -IsoPath "C:\Users\<windows-user>\Downloads\ubuntu-26.04-live-server-amd64.iso" `
  -DestinationDirectory "C:\VMs\Ubuntu-Template" `
  -StartInstaller
```

The script refuses to overwrite a non-empty destination. Complete the Ubuntu installation once in the Workstation console using:

- Hostname: `ubuntu-template`
- Username: `terraform`
- OpenSSH server: enabled
- Storage: use the entire virtual disk

During Ubuntu installation:

- Create the administrative account used by Terraform, such as `terraform`.
- Select **Install OpenSSH server**.
- Use the VMware NAT network.
- Install VMware Tools support:

```bash
sudo apt update
sudo apt install -y open-vm-tools openssh-server
sudo systemctl enable --now open-vm-tools ssh
```

Configure DHCP to identify clones by their generated VMware MAC address. Find the Netplan YAML under `/etc/netplan`, then ensure the Ethernet configuration includes:

```yaml
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: true
      dhcp-identifier: mac
```

The interface may be named something other than `ens33`. Apply it with:

```bash
sudo netplan apply
```

On Windows PowerShell, create the dedicated Terraform SSH key:

```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\vmware_monitoring"
```

Copy the template-prep script and public key into the VM, then run the script:

```powershell
scp .\scripts\prepare-ubuntu-template.sh terraform@TEMPLATE_IP:/tmp/prepare-ubuntu-template.sh
scp "$env:USERPROFILE\.ssh\vmware_monitoring.pub" terraform@TEMPLATE_IP:/tmp/vmware_monitoring.pub
ssh terraform@TEMPLATE_IP "sudo bash /tmp/prepare-ubuntu-template.sh /tmp/vmware_monitoring.pub"
```

The script installs OpenSSH and VMware Tools, authorizes the dedicated Terraform public key, enables lab sudo automation, cleans the machine identity, and powers the template off. The broad passwordless sudo rule is suitable for an isolated lab, not a production server.

Keep the template powered off when cloning it.

## 2. Clone the Workstation VMs

The target allocation is:

| VM | CPU | RAM | Suggested disk | Suggested IP |
|---|---:|---:|---:|---|
| `prometheus` | 2 | 4 GB | 30 GB | `192.168.100.10` |
| `kubernetes` | 2 | 8 GB | 50 GB | `192.168.100.11` |
| `grafana` | 2 | 4 GB | 30 GB | `192.168.100.12` |
| `jenkins` | 2 | 4 GB | 50 GB | `192.168.100.13` |

From elevated Windows PowerShell, run the Workstation bootstrap helper:

```powershell
cd C:\Path\To\vmware-workstation-terraform-lab

PowerShell -NoProfile -ExecutionPolicy Bypass -File .\scripts\New-WorkstationLab.ps1 `
  -TemplateVmx "C:\VMs\Ubuntu-Template\Ubuntu-Template.vmx" `
  -DestinationRoot "C:\VMs\Monitoring-Lab"
```

The helper:

- Creates full clones named `prometheus`, `kubernetes`, `grafana`, and `jenkins`
- Disconnects the Ubuntu installer ISO from every clone
- Assigns `2 CPU / 4 GB`, `2 CPU / 8 GB`, `2 CPU / 4 GB`, and `2 CPU / 4 GB`
- Starts all four guests without opening console windows
- Uses VMware Tools to discover their addresses
- Writes VMX paths and IP addresses to `workstation.auto.tfvars`
- Disables Terraform's second hardware edit because the helper has already applied it

If you already have four suitable Workstation VMs, skip cloning and enter their VMX paths and addresses directly in `terraform.tfvars`.

## 3. Verify Guest Access

Verify non-interactive key authentication to every cloned VM:

```powershell
ssh -o BatchMode=yes -i "$env:USERPROFILE\.ssh\vmware_monitoring" `
  terraform@PROMETHEUS_IP hostname

ssh -o BatchMode=yes -i "$env:USERPROFILE\.ssh\vmware_monitoring" `
  terraform@KUBERNETES_IP hostname

ssh -o BatchMode=yes -i "$env:USERPROFILE\.ssh\vmware_monitoring" `
  terraform@GRAFANA_IP hostname

ssh -o BatchMode=yes -i "$env:USERPROFILE\.ssh\vmware_monitoring" `
  terraform@JENKINS_IP hostname
```

If using existing VMs instead of clones, add the key to each VM:

```powershell
Get-Content "$env:USERPROFILE\.ssh\vmware_monitoring.pub" |
  ssh terraform@192.168.100.10 `
  "umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys"
```

Also add the sudo rule to each existing VM:

```bash
echo 'terraform ALL=(ALL) NOPASSWD:ALL' |
  sudo tee /etc/sudoers.d/terraform-monitoring-lab
sudo chmod 440 /etc/sudoers.d/terraform-monitoring-lab
sudo visudo -cf /etc/sudoers.d/terraform-monitoring-lab
```

Keep the SSH private key protected.

## 4. Configure Terraform

From Windows PowerShell:

```powershell
cd C:\Path\To\vmware-workstation-terraform-lab
Copy-Item terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
```

Set the SSH username, private key path, Workstation `vmrun.exe` path, and a strong Grafana password. If `workstation.auto.tfvars` was created by the clone helper, its VMX paths and IP addresses override the examples in `terraform.tfvars`.

Optional alert thresholds can be changed in `terraform.tfvars`:

```hcl
alert_cpu_threshold_percent       = 85
alert_memory_threshold_percent    = 85
alert_disk_threshold_percent      = 85
alert_container_restart_threshold = 3
```

`manage_workstation_hardware = true` requires all four guests to be powered off when Terraform first runs. Terraform writes a `.terraform-backup` beside each VMX file, applies the requested resources, then starts the guests headlessly when `start_workstation_vms = true`.

## 5. Apply

For the initial apply, power off all four VMs when `manage_workstation_hardware = true`. Terraform configures the VMX files, starts the guests, waits for SSH, and provisions all services in the same apply.

```powershell
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

This project uses Terraform's built-in `terraform_data` resource and does not download an external provider.

The Kubernetes step can take 10-15 minutes while K3s, Helm charts, and container images are installed.

To add Jenkins to an already-built lab, run the build helper with hardware edits skipped. This creates the missing `jenkins` clone, refreshes `workstation.auto.tfvars`, and applies the Jenkins Terraform resource:

```powershell
cd C:\Path\To\vmware-workstation-terraform-lab\scripts
.\Build-MonitoringLab.ps1 -SkipHardwareChanges
```

## 6. Verify

Terraform prints the service URLs. With the example addresses:

- Standalone Prometheus: `http://192.168.100.10:9090`
- Kubernetes Prometheus: `http://192.168.100.11:30090`
- Central Prometheus: `http://192.168.100.12:9090`
- Grafana: `http://192.168.100.12:3000`
- Jenkins: `http://192.168.100.13:8080`

Grafana username is `admin`; the password is `grafana_admin_password` from `terraform.tfvars`.

Check central Prometheus targets:

```text
http://192.168.100.12:9090/targets
```

Expected targets include:

- Four `node-exporter` targets
- Jenkins `node-exporter` target
- Central Prometheus
- Standalone Prometheus
- Kubernetes Prometheus
- Kubernetes federation

Check alert rules and firing alerts:

```text
http://192.168.100.12:9090/alerts
```

Check Kubernetes from the Kubernetes VM:

```bash
kubectl get nodes -o wide
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

Check Docker services:

```bash
# On the Prometheus VM
sudo docker compose -f /opt/monitoring/standalone/compose.yml ps

# On the Grafana VM
sudo docker compose -f /opt/monitoring/central/compose.yml ps

# On the Jenkins VM
sudo docker compose -f /opt/monitoring/jenkins/compose.yml ps
```

Get the initial Jenkins unlock password from the Jenkins VM:

```bash
sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

## Updating the Lab

Edit Terraform templates, dashboards, image variables, or Helm values and run:

```powershell
terraform plan
terraform apply
```

Configuration hashes are Terraform replacement triggers, so changed scripts and configurations are uploaded and rerun.

The image defaults use `latest` for convenience. Pin explicit Prometheus, Grafana, and Node Exporter tags in `terraform.tfvars` for long-lived environments.

The Grafana environment password only initializes a new Grafana database. Changing the Terraform variable later does not reset an existing Grafana user password.

## Publishing to GitHub

The repository includes a helper that initializes Git, verifies sensitive Terraform files are ignored, commits the safe lab code, and pushes it to GitHub.

Ignored local files include:

- `terraform.tfvars`
- `terraform.tfstate`
- `workstation.auto.tfvars`
- `.terraform/`
- build logs and status files
- private key file patterns

If you have the GitHub CLI installed and authenticated, create a private GitHub repository and push in one step:

```powershell
cd C:\Path\To\vmware-workstation-terraform-lab

.\scripts\Publish-ToGitHub.ps1 `
  -Repository "YOUR-GITHUB-USER/vmware-monitoring-lab" `
  -CreateRemote `
  -Visibility private
```

If you already created the GitHub repository, push to its URL:

```powershell
.\scripts\Publish-ToGitHub.ps1 `
  -RepositoryUrl "https://github.com/YOUR-GITHUB-USER/vmware-monitoring-lab.git"
```

Use `terraform.tfvars.example` for shareable example values. Keep real passwords, IP-specific runtime files, state, and SSH keys out of GitHub.

## Firewall Ports

If UFW is active, allow these ports from the VMware Workstation NAT subnet or, preferably, only from the relevant monitoring VM:

| Port | VM | Purpose |
|---:|---|---|
| 22 | All | Terraform SSH |
| 9100 | All | Node Exporter |
| 9090 | Prometheus and Grafana | Prometheus web/API |
| 30090 | Kubernetes | Kubernetes Prometheus NodePort |
| 3000 | Grafana | Grafana web UI |
| 8080 | Jenkins | Jenkins web UI |
| 50000 | Jenkins | Jenkins inbound agents |
| 6443 | Kubernetes | K3s API |

## Terraform Destroy

`terraform destroy` removes Terraform state resources but intentionally does not delete Workstation VMs or uninstall remote software. This avoids destroying virtual disks through a local provisioner. Delete cloned lab VMs through Workstation Pro when they are no longer needed.
