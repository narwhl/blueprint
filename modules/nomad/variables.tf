variable "supplychain" {
  type    = string
  default = "https://artifact.narwhl.dev/upstream/current.json"
}

variable "data_dir" {
  type        = string
  default     = "/opt/nomad"
  description = "Directory for storing runtime data for Nomad"
}

variable "datacenter_name" {
  type        = string
  description = "Name of datacenter nomad server will use to identify itself"
  validation {
    condition     = length(var.datacenter_name) > 0
    error_message = "Datacenter name cannot be empty"
  }
}

variable "listen_addr" {
  type        = string
  default     = "0.0.0.0"
  description = "Address to bind the Nomad agent to"
}

variable "advertise_addr" {
  type        = string
  default     = "{{ GetPrivateIP }}"
  description = "Address to advertise for Nomad agent"
}

variable "disable_client" {
  type        = bool
  default     = false
  description = "Disable client mode for Nomad agent"
}

variable "log_level" {
  type        = string
  default     = "INFO"
  description = "Log level for Nomad agent"
  validation {
    condition     = var.log_level == "DEBUG" || var.log_level == "INFO" || var.log_level == "WARN"
    error_message = "Log level must be one of debug, info, warn"
  }
}

variable "role" {
  type        = string
  default     = "server"
  description = "Role of the Nomad agent"
  validation {
    condition     = var.role == "client" || var.role == "server"
    error_message = "Role must be either client or server"
  }
}

variable "nomad_user" {
  type        = string
  default     = ""
  description = "User running Nomad. Needs to be root if running exec plugin. Defaults to nomad if role is server, or root if role is client"
}

variable "nomad_group" {
  type        = string
  default     = ""
  description = "Group of user running Nomad. For setting file permissions in config. Defaults to nomad if role is server, or root if role is client"
}

variable "bootstrap_expect" {
  type        = number
  default     = 1
  description = "Number of nomad instance connection expected to form the cluster"

  validation {
    condition     = var.bootstrap_expect % 2 == 1
    error_message = "Bootstrap Expect cannot be even number due to the inability to reach consensus in a quorum"
  }

  validation {
    condition     = var.bootstrap_expect > 0
    error_message = "Bootstrap Expect cannot be zero or negative"
  }
}

variable "gossip_key" {
  type        = string
  description = "Gossip Encryption Key for Nomad inter-server communications"
  default     = ""
  sensitive   = true
}

variable "tls" {
  type = object({
    enable = bool
    ca_file = optional(object({
      path    = string
      content = string
    }))
    cert_file = optional(object({
      path    = string
      content = string
    }))
    key_file = optional(object({
      path    = string
      content = string
    }))
  })
  default = {
    enable = false
  }
  description = "TLS configuration for Nomad. Set enable=true to activate TLS and provide cert/key/ca objects."
  validation {
    condition     = !var.tls.enable || (var.tls.ca_file != null && var.tls.cert_file != null && var.tls.key_file != null)
    error_message = "When TLS is enabled, ca_file, cert_file, and key_file must be set."
  }
}

variable "host_volume" {
  type = map(object({
    path             = string
    read_only        = bool
    create_directory = optional(bool, false)
  }))
  default     = {}
  description = "Host volume configuration for Nomad"
}

resource "random_id" "gossip_key" {
  byte_length = 32
}

locals {
  gossip_key = length(var.gossip_key) > 0 ? var.gossip_key : random_id.gossip_key.b64_std
}
