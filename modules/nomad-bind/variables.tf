variable "job_name" {
  description = "The name of the Nomad job"
  type        = string
  default     = "bind"
}

variable "datacenter_name" {
  description = "The datacenter to deploy the job"
  type        = string
  default     = "dc1"

  validation {
    condition     = length(var.datacenter_name) > 0
    error_message = "Datacenter name cannot be empty"
  }
}

variable "namespace" {
  description = "The namespace to deploy the job"
  type        = string
  default     = "default"
}

variable "upstream_nameservers" {
  description = "The list of upstream nameservers"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
  validation {
    condition     = length(var.upstream_nameservers) > 0
    error_message = "Must provide at least one upstream nameserver"
  }
}

variable "tsig_algorithm" {
  type        = string
  default     = "hmac-sha256"
  description = "The TSIG algorithm to use"
  validation {
    condition     = contains(["hmac-sha1", "hmac-sha224", "hmac-sha256", "hmac-sha384", "hmac-sha512"], var.tsig_algorithm)
    error_message = "Invalid TSIG algorithm"
  }
}

variable "tsig_key_name" {
  type        = string
  default     = "tsig"
  description = "The name of the TSIG key"
}

variable "zones" {
  description = "The list of zones"
  type        = list(string)
  validation {
    condition     = length(var.zones) > 0
    error_message = "Must provide at least one zone"
  }
}

variable "bind_version" {
  description = "The version of BIND to deploy"
  type        = string
}

variable "tailscale_version" {
  description = "The version of Tailscale to deploy"
  type        = string
  default     = "stable"
}

variable "tailscale_oauth_client_id" {
  type        = string
  description = "The Tailscale OAuth client ID"
}

variable "tailscale_oauth_client_secret" {
  type        = string
  description = "The Tailscale OAuth client secret"
  sensitive   = true
}

variable "tailscale_authkey" {
  description = "The Tailscale authkey"
  type        = string
  sensitive   = true
}

variable "purge_on_destroy" {
  type        = bool
  default     = false
  description = "Purge the Typesense Nomad job on destroy"
}

variable "resources" {
  type = object({
    cpu    = optional(number, 300)
    memory = optional(number, 256)
  })
  default = {
    cpu    = 300
    memory = 256
  }
  description = "Resources to allocate to the job with"
}
