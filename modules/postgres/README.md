# Terraform module for running PostgreSQL

This module only works with Debian currently. This module only installs the `postgresql` package without additional
configuration. You will need to use `nomad-postgres` module to configure and run PostgreSQL.

## Usage

To run `nomad-postgres` module, you need to configure 3 host volumes `postgres-data`, `postgres-socket` and
`postgres-log` mounting paths specified below and pass their volume name in `nomad-postgres` module configuration.

```terraform
module "postgres" {
  source = "github.com/narwhl/blueprint//modules/postgres"
}

module "nomad" {
  source = "github.com/narwhl/blueprint//modules/nomad"
  datacenter_name = "dc1"
  role            = "server"
  host_volume     = {
    "postgres-data" = {
      path = "/var/lib/postgresql"
      read_only = false
    }
    "postgres-socket" = {
      path = "/var/run/postgresql"
      read_only = false
    }
    "postgres-log" = {
      path = "/var/log/postgresql"
      read_only = false
    }
  }
}
```
