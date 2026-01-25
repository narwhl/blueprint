variable "controller_job_name" {
  type    = string
  default = "ingress-controller"
}

variable "gateway_job_name" {
  type    = string
  default = "ingress-gateway"
}

variable "dns_zone_name" {
  type        = string
  description = "Name of the DNS zone"
  validation {
    condition     = length(var.dns_zone_name) > 0
    error_message = "DNS zone name cannot be empty"
  }
}

variable "cloudflare_account_id" {
  type        = string
  sensitive   = true
  description = "Cloudflare account ID. Leave empty to disable ingress from cloudflare tunnel"
}

variable "cloudflare_tunnel_name" {
  type        = string
  description = "Name of the cloudflare tunnel. If not provided, the name will be ingress-<generated-random-string>."
  default     = ""
}

variable "cloudflare_tunnel_config_source" {
  type        = string
  description = "Source of the cloudflare tunnel config. Either `local` or `cloudflare`. If `local` is used, the tunnel config will be generated locally. If `cloudflare` is used, the tunnel config will be configured by `cloudflare_tunnel_config` resource."
  validation {
    condition     = contains(["local", "cloudflare"], var.cloudflare_tunnel_config_source)
    error_message = "Invalid cloudflare_tunnel_config_source value. Valid values are `local` and `cloudflare`."
  }
  default = "cloudflare"
}

variable "acme_email" {
  type        = string
  default     = ""
  description = "Email address used for acme registration"
}

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

variable "traefik_version" {
  type        = string
  description = "Version of traefik to deploy"
  validation {
    condition     = length(var.traefik_version) > 0
    error_message = "Traefik version cannot be empty"
  }
}

variable "cloudflared_version" {
  type        = string
  description = "Version of cloudflared to deploy"
  validation {
    condition     = length(var.cloudflared_version) > 0
    error_message = "Cloudflared version cannot be empty"
  }
}

variable "static_routes" {
  type        = string
  description = "Traefik dynamic configuration for configuring static routes"
  default     = ""
}

variable "nomad_provider_config" {
  type = object({
    address = optional(string, "")
  })
  default     = null
  description = "Configuration for Nomad Traefik integration. The address from Cousul `nomad` service will be used if address is left empty. TLS is not supported at the moment. Note that nomad service discovery will only enable if the config value is not null. You need to supply an empty object if you use all defaulted values."
}

variable "consul_provider_config" {
  type = object({
    address       = optional(string, "")
    connect_aware = optional(bool, true)
    service_name  = optional(string, "")
  })
  default     = null
  description = "Configuration for Consul Traefik integration. The address from Consul `consul` service will be used if address is left empty. TLS is not supported at the moment. Note that consul service discovery will only enable if the config value is not null. You need to supply an empty object if you use all defaulted values."
}

variable "use_https" {
  type        = bool
  description = "Whether to use https for ingress"
  default     = false
}

variable "enable_http_to_https_redirect" {
  type        = bool
  description = "Whether to redirect HTTP traffic to HTTPS"
  default     = false
}
