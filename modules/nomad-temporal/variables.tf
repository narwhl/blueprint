variable "job_name" {
  type    = string
  default = "temporal"
}

variable "service_name" {
  type        = string
  description = "Name of the service advertised to service discovery"
  default     = "temporal"
}

variable "datacenter_name" {
  type        = string
  description = "Name of datacenter to deploy jobs to"
  default     = "dc1"
  validation {
    condition     = length(var.datacenter_name) > 0
    error_message = "Datacenter name must be set"
  }
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "postgres_host" {
  type        = string
  description = "Hostname for Postgres"
  default     = "{{ with service `postgres-rw` }}{{ with index . 0 }}{{ .Address }}{{ end }}{{ end }}"
}

variable "postgres_port" {
  type        = string
  description = "Port for Postgres"
  default     = "{{ with service `postgres-rw` }}{{ with index . 0 }}{{ .Port }}{{ end }}{{ end }}"
}

variable "postgres_username" {
  type        = string
  description = "Username for authenticating to Postgres"
  default     = "temporal"
  validation {
    condition     = length(var.postgres_username) > 0
    error_message = "Postgres username cannot be empty"
  }
}

variable "postgres_password" {
  type        = string
  description = "Password for authenticating to Postgres"
  validation {
    condition     = length(var.postgres_password) > 0
    error_message = "Postgres password cannot be empty"
  }
}

variable "postgres_database" {
  type        = string
  description = "Database name for Postgres"
  default     = "temporal"
  validation {
    condition     = length(var.postgres_database) > 0
    error_message = "Postgres database cannot be empty"
  }
}

variable "postgres_visibility_database" {
  type        = string
  description = "Visibility database name for Postgres"
  default     = "temporal_visibility"
  validation {
    condition     = length(var.postgres_visibility_database) > 0
    error_message = "Postgres visibility database cannot be empty"
  }
}

variable "temporal_version" {
  type        = string
  description = "Temporal server version"
  validation {
    condition     = length(var.temporal_version) > 0
    error_message = "Temporal server version must be set"
  }
}

variable "temporal_ui_version" {
  type        = string
  description = "Temporal UI version"
  validation {
    condition     = length(var.temporal_ui_version) > 0
    error_message = "Temporal UI version must be set"
  }
}

variable "purge_on_destroy" {
  type        = bool
  description = "Whether to purge all Temporal jobs on destroy"
  default     = false
}
