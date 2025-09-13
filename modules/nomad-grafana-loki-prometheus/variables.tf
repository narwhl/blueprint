variable "datacenter_name" {
  type        = string
  description = "Name of the datacenter"
  validation {
    condition     = length(var.datacenter_name) > 0
    error_message = "Datacenter name cannot be empty"
  }
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "job_name" {
  default     = "monitoring"
  description = "Nomad job name"
}

variable "purge_on_destroy" {
  type        = bool
  default     = false
  description = "Purge the Nomad job on destroy"
}

variable "grafana_version" {
  type        = string
  default     = "latest"
  description = "Version of Grafana to deploy"
}

variable "loki_version" {
  type        = string
  default     = "latest"
  description = "Version of Loki to deploy"
}

variable "prometheus_version" {
  type        = string
  default     = "latest"
  description = "Version of Prometheus to deploy"
}

variable "resources" {
  type = map(object({
    cpu    = optional(number, 1000)
    memory = optional(number, 2048)
  }))
  default = {
    grafana : {
      cpu    = 300
      memory = 512
    }
    loki : {
      cpu    = 500
      memory = 1024
    }
    prometheus : {
      cpu    = 1000
      memory = 2048
    }
  }
  description = "Resources to run the job with"
}

variable "service_name_grafana" {
  type        = string
  default     = "grafana"
  description = "The name of the Grafana service"
}

variable "service_name_loki" {
  type        = string
  default     = "loki"
  description = "The name of the Loki service"
}

variable "service_name_prometheus" {
  type        = string
  default     = "prometheus"
  description = "The name of the Prometheus service"
}

variable "grafana_admin_password" {
  type        = string
  sensitive   = true
  description = "Grafana admin password. Leave blank to generate a new one with Terraform random resource."
  default     = ""
}
