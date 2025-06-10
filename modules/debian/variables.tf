variable "supplychain" {
  type    = string
  default = "https://artifact.narwhl.dev/upstream/current.json"
}

variable "name" {
  type        = string
  description = "Hostname of the Debian VM"
}

variable "default_packages" {
  type = list(string)
  default = [
    "apt-transport-https",
    "ca-certificates",
    "curl",
    "dnsutils",
    "gnupg",
    "git",
    "gzip",
    "lsb-release",
    "net-tools",
    "qemu-guest-agent",
    "rsync",
    "software-properties-common",
    "sudo",
    "tar",
    "vim",
    "unzip",
    "zip",
    "zstd",
    "containerd.io",
    "docker-ce",
    "docker-ce-cli",
    "docker-buildx-plugin",
    "docker-compose-plugin",
    "jq",
    "podman",
  ]
}

variable "expose_metrics" {
  type        = bool
  default     = false
  description = "Whether to enable prometheus node-exporter as system service container"
}

variable "username" {
  type        = string
  default     = "system"
  description = "Login user"
  validation {
    condition     = length(var.username) > 0
    error_message = "Username must be set"
  }
}

variable "password" {
  type        = string
  description = "Login password in console, ssh login is key only."
  default     = ""
  sensitive   = true
}

variable "autologin" {
  type        = bool
  description = "Disables authentication requirement for tty1 console"
  default     = false
}

variable "ssh_authorized_keys" {
  type        = list(string)
  description = "SSH public keys"
  default     = []
}

variable "ssh_keys_import" {
  type        = list(string)
  description = "List of SSH key import IDs through provider URLs"
  default     = []
  validation {
    condition     = length(var.ssh_keys_import) == 0 || alltrue([for item in var.ssh_keys_import : startswith(item, "http")])
    error_message = "SSH key import ID must be a valid URL"
  }
}

variable "timezone" {
  type        = string
  default     = "Asia/Hong_Kong"
  description = "Timezone for the Debian VM"
}

variable "disks" {
  type = list(object({
    label       = string
    mount_path  = string
    device_path = string
  }))
  default     = []
  description = "List of disk configurations"
}

variable "expose_docker_socket" {
  type        = bool
  default     = false
  description = "Whether to expose the Docker socket to the VM"
}

variable "network" {
  type        = string
  default     = ""
  description = "Subnet the VM resided in"
}

variable "ip_address" {
  type        = string
  default     = ""
  description = "CIDR for the Debian VM"
}

variable "gateway_ip" {
  type        = string
  default     = ""
  description = "Gateway IP for the Debian VM"
}

variable "nameservers" {
  type        = list(string)
  default     = ["1.1.1.1"]
  description = "Nameservers for the Debian VM"
}

variable "ca_certs" {
  type        = list(string)
  description = "CA certificates for the Debian VM"
  default     = []
}

variable "substrates" {
  type = list(object({
    files = list(object({
      path    = string
      content = string
      enabled = optional(bool, true)
      mode    = optional(string, "0644")
      owner   = optional(string, "root")
      group   = optional(string, "root")
      defer   = optional(bool, false)
      tags    = string
    }))
    directories = optional(list(object({
      path    = string
      enabled = optional(bool, true)
      mode    = optional(string, "755")
      owner   = optional(string, "root")
      group   = optional(string, "root")
      tags    = optional(string, "ignition") # only ignition is specified for backward compatibility
    })), [])
    install = object({
      systemd_units = list(object({
        name    = string
        content = string
      }))
      repositories = list(string)
      packages     = list(string)
    })
    users = list(object({
      name     = string
      home_dir = string
    }))
  }))
  default     = []
  description = "List of substrate configurations"
}

variable "additional_packages" {
  type    = list(string)
  default = []
}

variable "startup_script" {
  type = object({
    override_default = optional(bool, false)
    inline           = list(string)
  })
  default = {
    override_default = false
    inline           = []
  }
}

variable "base64_encode" {
  type        = bool
  default     = false
  description = "Whether to base64 encode the configuration"
}

