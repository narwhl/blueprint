# Terraform module for running PostgreSQL on Nomad

This module only works with Debian currently. This module assumes the `postgresql` package is installed in the host
Debian system.

## Usage

```terraform
module "nomad_postgres" {
  source = "github.com/narwhl/blueprint//modules/nomad-postgres"
  datacenter_name = "dc1"
  pgbackrest_s3_config = {
    endpoint   = "https://${data.cloudflare_accounts.cf_account.accounts[0].id}.r2.cloudflarestorage.com"
    bucket     = cloudflare_r2_bucket.pgbackrest.name
    access_key = "<access_key>"
    secret_key = "<secret_key>"
    region     = "us-east-1"
  }
  restore_backup = true
}
```

## Configuration

`datacenter_name`: The name of the Nomad datacenter to use.

`pgbackrest_s3_config`: The configuration for pgbackrest to use.

`restore_backup`: Whether to restore a backup. Defaults to `false`. If true, the restore job will be run instead of the
initialization job to restore the database.
