locals {
  pgbackrest_conf = templatefile(
    "${path.module}/templates/pgbackrest.conf.tftpl",
    {
      s3_endpoint       = var.pgbackrest_s3_config.endpoint
      s3_bucket         = var.pgbackrest_s3_config.bucket
      s3_access_key     = var.pgbackrest_s3_config.access_key
      s3_secret_key     = var.pgbackrest_s3_config.secret_key
      s3_region         = var.pgbackrest_s3_config.region
      pgbackrest_stanza = var.pgbackrest_stanza
    }
  )
}

resource "nomad_job" "postgres" {
  jobspec = templatefile(
    "${path.module}/templates/postgres.nomad.hcl.tftpl",
    {
      job_name          = var.postgres_job_name
      datacenter_name   = var.datacenter_name
      pgbackrest_conf   = local.pgbackrest_conf
      pgbackrest_stanza = var.pgbackrest_stanza
    }
  )
}

resource "nomad_job" "pgbackrest" {
  jobspec = templatefile(
    "${path.module}/templates/pgbackrest.nomad.hcl.tftpl",
    {
      job_name          = var.pgbackrest_job_name
      datacenter_name   = var.datacenter_name
      pgbackrest_conf   = local.pgbackrest_conf
      pgbackrest_stanza = var.pgbackrest_stanza
      backup_schedule   = var.backup_schedule
    }
  )
}

resource "nomad_job" "pgbackrest_init" {
  jobspec = templatefile(
    "${path.module}/templates/pgbackrest-init.nomad.hcl.tftpl",
    {
      job_name          = var.pgbackrest_init_job_name
      datacenter_name   = var.datacenter_name
      pgbackrest_conf   = local.pgbackrest_conf
      pgbackrest_stanza = var.pgbackrest_stanza
    }
  )
}
