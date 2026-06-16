resource "terraform_data" "workstation_vms" {
  triggers_replace = {
    vmrun_path      = var.workstation_vmrun_path
    prometheus_vmx  = var.prometheus_vmx_path
    kubernetes_vmx  = var.kubernetes_vmx_path
    grafana_vmx     = var.grafana_vmx_path
    jenkins_vmx     = var.jenkins_vmx_path
    manage_hardware = tostring(var.manage_workstation_hardware)
    start_vms       = tostring(var.start_workstation_vms)
    script_hash     = filesha256("${path.module}/scripts/Manage-WorkstationVMs.ps1")
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = "& '${path.module}/scripts/Manage-WorkstationVMs.ps1' -VmrunPath '${var.workstation_vmrun_path}' -PrometheusVmx '${var.prometheus_vmx_path}' -KubernetesVmx '${var.kubernetes_vmx_path}' -GrafanaVmx '${var.grafana_vmx_path}' -JenkinsVmx '${var.jenkins_vmx_path}' -ManageHardware ${var.manage_workstation_hardware ? 1 : 0} -StartVms ${var.start_workstation_vms ? 1 : 0}"
  }
}

resource "terraform_data" "standalone_prometheus" {
  depends_on = [terraform_data.workstation_vms]

  triggers_replace = {
    host        = var.prometheus_vm.address
    config_hash = sha256(local.standalone_prometheus_config)
    script_hash = filesha256("${path.module}/scripts/install-standalone-prometheus.sh")
    docker_hash = filesha256("${path.module}/scripts/install-docker.sh")
    images      = "${var.prometheus_image}|${var.node_exporter_image}"
  }

  connection {
    type        = "ssh"
    host        = var.prometheus_vm.address
    port        = var.ssh_port
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "2m"
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p /tmp/terraform-monitoring"]
  }

  provisioner "file" {
    content     = local.standalone_prometheus_config
    destination = "/tmp/terraform-monitoring/prometheus.yml"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install-standalone-prometheus.sh"
    destination = "/tmp/terraform-monitoring/install.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install-docker.sh"
    destination = "/tmp/terraform-monitoring/install-docker.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 700 /tmp/terraform-monitoring/install.sh /tmp/terraform-monitoring/install-docker.sh",
      "sudo -n env HOST_NAME='${var.prometheus_vm.name}' PROMETHEUS_IMAGE='${var.prometheus_image}' NODE_EXPORTER_IMAGE='${var.node_exporter_image}' /tmp/terraform-monitoring/install.sh"
    ]
  }
}

resource "terraform_data" "kubernetes" {
  depends_on = [terraform_data.workstation_vms]

  triggers_replace = {
    host          = var.kubernetes_vm.address
    values_hash   = sha256(local.kubernetes_values)
    script_hash   = filesha256("${path.module}/scripts/install-kubernetes-monitoring.sh")
    chart_version = var.kube_prometheus_stack_chart_version
  }

  connection {
    type        = "ssh"
    host        = var.kubernetes_vm.address
    port        = var.ssh_port
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "2m"
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p /tmp/terraform-monitoring"]
  }

  provisioner "file" {
    content     = local.kubernetes_values
    destination = "/tmp/terraform-monitoring/kube-prometheus-values.yml"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install-kubernetes-monitoring.sh"
    destination = "/tmp/terraform-monitoring/install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 700 /tmp/terraform-monitoring/install.sh",
      "sudo -n env HOST_NAME='${var.kubernetes_vm.name}' SSH_USER='${var.ssh_user}' CHART_VERSION='${var.kube_prometheus_stack_chart_version}' /tmp/terraform-monitoring/install.sh"
    ]
  }
}

resource "terraform_data" "jenkins" {
  depends_on = [terraform_data.workstation_vms]

  triggers_replace = {
    host        = var.jenkins_vm.address
    script_hash = filesha256("${path.module}/scripts/install-jenkins.sh")
    docker_hash = filesha256("${path.module}/scripts/install-docker.sh")
    images      = "${var.jenkins_image}|${var.node_exporter_image}"
  }

  connection {
    type        = "ssh"
    host        = var.jenkins_vm.address
    port        = var.ssh_port
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "2m"
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p /tmp/terraform-monitoring"]
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install-jenkins.sh"
    destination = "/tmp/terraform-monitoring/install.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install-docker.sh"
    destination = "/tmp/terraform-monitoring/install-docker.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 700 /tmp/terraform-monitoring/install.sh /tmp/terraform-monitoring/install-docker.sh",
      "sudo -n env HOST_NAME='${var.jenkins_vm.name}' JENKINS_IMAGE='${var.jenkins_image}' NODE_EXPORTER_IMAGE='${var.node_exporter_image}' /tmp/terraform-monitoring/install.sh"
    ]
  }
}

resource "terraform_data" "central_monitoring" {
  depends_on = [
    terraform_data.standalone_prometheus,
    terraform_data.kubernetes,
    terraform_data.jenkins
  ]

  triggers_replace = {
    host             = var.grafana_vm.address
    prometheus_hash  = sha256(local.central_prometheus_config)
    alert_rules_hash = sha256(local.central_alert_rules)
    datasources_hash = sha256(local.grafana_datasources)
    dashboard_hashes = "${filesha256("${path.module}/dashboards/node-overview.json")}|${filesha256("${path.module}/dashboards/kubernetes-overview.json")}"
    script_hash      = filesha256("${path.module}/scripts/install-central-monitoring.sh")
    docker_hash      = filesha256("${path.module}/scripts/install-docker.sh")
    password_hash    = sha256(var.grafana_admin_password)
    images           = "${var.prometheus_image}|${var.node_exporter_image}|${var.grafana_image}"
  }

  connection {
    type        = "ssh"
    host        = var.grafana_vm.address
    port        = var.ssh_port
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/terraform-monitoring",
      "mkdir -p /tmp/terraform-monitoring/grafana/provisioning/datasources",
      "mkdir -p /tmp/terraform-monitoring/grafana/provisioning/dashboards",
      "mkdir -p /tmp/terraform-monitoring/grafana/dashboards"
    ]
  }

  provisioner "file" {
    content     = local.central_prometheus_config
    destination = "/tmp/terraform-monitoring/prometheus.yml"
  }

  provisioner "file" {
    content     = local.central_alert_rules
    destination = "/tmp/terraform-monitoring/alerts.yml"
  }

  provisioner "file" {
    content     = local.grafana_datasources
    destination = "/tmp/terraform-monitoring/grafana/provisioning/datasources/prometheus.yml"
  }

  provisioner "file" {
    source      = "${path.module}/config/grafana-dashboard-provider.yml"
    destination = "/tmp/terraform-monitoring/grafana/provisioning/dashboards/default.yml"
  }

  provisioner "file" {
    source      = "${path.module}/dashboards/node-overview.json"
    destination = "/tmp/terraform-monitoring/grafana/dashboards/node-overview.json"
  }

  provisioner "file" {
    source      = "${path.module}/dashboards/kubernetes-overview.json"
    destination = "/tmp/terraform-monitoring/grafana/dashboards/kubernetes-overview.json"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install-central-monitoring.sh"
    destination = "/tmp/terraform-monitoring/install.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install-docker.sh"
    destination = "/tmp/terraform-monitoring/install-docker.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 700 /tmp/terraform-monitoring/install.sh /tmp/terraform-monitoring/install-docker.sh",
      "sudo -n env HOST_NAME='${var.grafana_vm.name}' PROMETHEUS_IMAGE='${var.prometheus_image}' NODE_EXPORTER_IMAGE='${var.node_exporter_image}' GRAFANA_IMAGE='${var.grafana_image}' GRAFANA_ADMIN_PASSWORD_B64='${base64encode(var.grafana_admin_password)}' /tmp/terraform-monitoring/install.sh"
    ]
  }
}
