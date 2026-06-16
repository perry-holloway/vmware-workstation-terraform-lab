output "services" {
  value = {
    standalone_prometheus = "http://${var.prometheus_vm.address}:9090"
    kubernetes_api        = "https://${var.kubernetes_vm.address}:6443"
    kubernetes_prometheus = "http://${var.kubernetes_vm.address}:${var.kubernetes_prometheus_node_port}"
    central_prometheus    = "http://${var.grafana_vm.address}:9090"
    grafana               = "http://${var.grafana_vm.address}:3000"
    jenkins               = "http://${var.jenkins_vm.address}:8080"
  }
}

output "grafana_username" {
  value = "admin"
}
