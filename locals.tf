locals {
  standalone_prometheus_config = templatefile("${path.module}/templates/standalone-prometheus.yml.tftpl", {
    scrape_interval = var.scrape_interval
  })

  central_prometheus_config = templatefile("${path.module}/templates/central-prometheus.yml.tftpl", {
    scrape_interval                 = var.scrape_interval
    prometheus_name                 = var.prometheus_vm.name
    prometheus_address              = var.prometheus_vm.address
    kubernetes_name                 = var.kubernetes_vm.name
    kubernetes_address              = var.kubernetes_vm.address
    grafana_name                    = var.grafana_vm.name
    grafana_address                 = var.grafana_vm.address
    jenkins_name                    = var.jenkins_vm.name
    jenkins_address                 = var.jenkins_vm.address
    kubernetes_prometheus_node_port = var.kubernetes_prometheus_node_port
  })

  central_alert_rules = templatefile("${path.module}/templates/central-alerts.yml.tftpl", {
    cpu_threshold     = var.alert_cpu_threshold_percent
    memory_threshold  = var.alert_memory_threshold_percent
    disk_threshold    = var.alert_disk_threshold_percent
    restart_threshold = var.alert_container_restart_threshold
  })

  grafana_datasources = templatefile("${path.module}/templates/grafana-datasources.yml.tftpl", {
    kubernetes_address              = var.kubernetes_vm.address
    kubernetes_prometheus_node_port = var.kubernetes_prometheus_node_port
    scrape_interval                 = var.scrape_interval
  })

  kubernetes_values = templatefile("${path.module}/templates/kube-prometheus-values.yml.tftpl", {
    kubernetes_prometheus_node_port = var.kubernetes_prometheus_node_port
  })
}
