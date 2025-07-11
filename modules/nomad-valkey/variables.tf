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
  default     = "valkey"
  description = "Nomad job name"
}

variable "valkey_version" {
  default     = "8"
  description = "valkey version to be deployed"
}

variable "host_volume_config" {
  type = object({
    source    = string
    read_only = optional(bool, false)
  })
  nullable    = true
  default     = null
  description = "Host volume configuration for storing valkey data"
}

variable "enable_ephemeral_disk" {
  type        = bool
  default     = false
  description = "Enable Nomad ephemeral disk for the storing valkey data temporarily. Cannot be used with host volumes."
}

variable "purge_on_destroy" {
  type        = bool
  default     = false
  description = "Purge the Typesense Nomad job on destroy"
}

variable "persistent_config" {
  type = object({
    save_options = optional(string, "60 1")
  })
  description = "Persistent configuration for valkey"
}

variable "resources" {
  type = object({
    cpu    = optional(number, 1000)
    memory = optional(number, 2048)
  })
  default = {
    cpu    = 1000
    memory = 2048
  }
  description = "Resources to run the job with"
}
