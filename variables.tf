variable "ssh_user" {
  description = "Linux account used by Terraform on all lab VMs. It must have passwordless sudo for this lab."
  type        = string
  default     = "terraform"
}

variable "ssh_private_key_path" {
  description = "Absolute path to the private SSH key authorized on all four VMs."
  type        = string
}

variable "ssh_port" {
  description = "SSH port used by all VMs."
  type        = number
  default     = 22

  validation {
    condition     = var.ssh_port >= 1 && var.ssh_port <= 65535 && floor(var.ssh_port) == var.ssh_port
    error_message = "ssh_port must be a whole number between 1 and 65535."
  }
}

variable "prometheus_vm" {
  description = "Standalone Prometheus VM connection details."
  type = object({
    name    = string
    address = string
  })
}

variable "kubernetes_vm" {
  description = "Single-node K3s VM connection details."
  type = object({
    name    = string
    address = string
  })
}

variable "grafana_vm" {
  description = "Central Grafana and Prometheus VM connection details."
  type = object({
    name    = string
    address = string
  })
}

variable "jenkins_vm" {
  description = "Jenkins VM connection details."
  type = object({
    name    = string
    address = string
  })
}

variable "grafana_admin_password" {
  description = "Initial password for the central Grafana admin account."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.grafana_admin_password) >= 12
    error_message = "Use a Grafana password containing at least 12 characters."
  }
}

variable "scrape_interval" {
  description = "Prometheus scrape interval."
  type        = string
  default     = "15s"

  validation {
    condition     = can(regex("^[1-9][0-9]*(ms|s|m|h|d|w|y)$", var.scrape_interval))
    error_message = "scrape_interval must be a positive Prometheus duration such as 15s, 1m, or 1h."
  }
}

variable "alert_cpu_threshold_percent" {
  description = "CPU usage percentage that triggers the HostHighCpuUsage alert."
  type        = number
  default     = 85

  validation {
    condition     = var.alert_cpu_threshold_percent > 0 && var.alert_cpu_threshold_percent <= 100
    error_message = "alert_cpu_threshold_percent must be greater than 0 and no more than 100."
  }
}

variable "alert_memory_threshold_percent" {
  description = "Memory usage percentage that triggers the HostHighMemoryUsage alert."
  type        = number
  default     = 85

  validation {
    condition     = var.alert_memory_threshold_percent > 0 && var.alert_memory_threshold_percent <= 100
    error_message = "alert_memory_threshold_percent must be greater than 0 and no more than 100."
  }
}

variable "alert_disk_threshold_percent" {
  description = "Filesystem usage percentage that triggers the HostHighFilesystemUsage alert."
  type        = number
  default     = 85

  validation {
    condition     = var.alert_disk_threshold_percent > 0 && var.alert_disk_threshold_percent <= 100
    error_message = "alert_disk_threshold_percent must be greater than 0 and no more than 100."
  }
}

variable "alert_container_restart_threshold" {
  description = "Container restart count in 15 minutes that triggers the KubernetesContainerRestarting alert."
  type        = number
  default     = 3

  validation {
    condition     = var.alert_container_restart_threshold >= 0 && floor(var.alert_container_restart_threshold) == var.alert_container_restart_threshold
    error_message = "alert_container_restart_threshold must be a non-negative whole number."
  }
}

variable "kubernetes_prometheus_node_port" {
  description = "NodePort used to expose Kubernetes Prometheus to the central Grafana VM."
  type        = number
  default     = 30090

  validation {
    condition     = var.kubernetes_prometheus_node_port >= 30000 && var.kubernetes_prometheus_node_port <= 32767 && floor(var.kubernetes_prometheus_node_port) == var.kubernetes_prometheus_node_port
    error_message = "kubernetes_prometheus_node_port must be a whole number in the Kubernetes NodePort range 30000-32767."
  }
}

variable "kube_prometheus_stack_chart_version" {
  description = "Pinned kube-prometheus-stack Helm chart version."
  type        = string
  default     = "86.2.0"
}

variable "prometheus_image" {
  type    = string
  default = "prom/prometheus:latest"
}

variable "node_exporter_image" {
  type    = string
  default = "prom/node-exporter:latest"
}

variable "grafana_image" {
  type    = string
  default = "grafana/grafana:latest"
}

variable "jenkins_image" {
  type    = string
  default = "jenkins/jenkins:lts-jdk21"
}

variable "workstation_vmrun_path" {
  description = "Path to vmrun.exe installed with VMware Workstation Pro."
  type        = string
  default     = "C:/Program Files/VMware/VMware Workstation/vmrun.exe"
}

variable "manage_workstation_hardware" {
  description = "Update CPU and RAM in the VMX files. The VMs must be powered off when this is true."
  type        = bool
  default     = true
}

variable "start_workstation_vms" {
  description = "Start the four VMs headlessly with vmrun before SSH provisioning."
  type        = bool
  default     = true
}

variable "prometheus_vmx_path" {
  description = "Absolute path to the standalone Prometheus VMX file."
  type        = string
}

variable "kubernetes_vmx_path" {
  description = "Absolute path to the Kubernetes VMX file."
  type        = string
}

variable "grafana_vmx_path" {
  description = "Absolute path to the central Grafana VMX file."
  type        = string
}

variable "jenkins_vmx_path" {
  description = "Absolute path to the Jenkins VMX file."
  type        = string
}
