variable "postgres_job_name" {
  type    = string
  default = "postgres"
}

variable "backup_schedule" {
  type        = string
  default     = "@weekly"
  description = "Backup schedule in cron syntax"
}

variable "pgbackrest_job_name" {
  type    = string
  default = "pgbackrest"
}

variable "pgbackrest_init_job_name" {
  type    = string
  default = "pgbackrest-init"
}

variable "datacenter_name" {
  type        = string
  description = "Name of the datacenter"
  validation {
    condition     = length(var.datacenter_name) > 0
    error_message = "Datacenter name cannot be empty"
  }
}

variable "pgbackrest_s3_config" {
  type = object({
    endpoint   = string
    bucket     = string
    access_key = string
    secret_key = string
    region     = string
  })
  sensitive   = true
  description = "The pgBackRest repo S3 configuration"
}

variable "pgbackrest_stanza" {
  type        = string
  default     = "db-primary"
  description = "The pgBackRest stanza to use"
}



