# Terraform module for self hosting Redis on Nomad

## Usage

```hcl
module "redis" {
  source                = "github.com/narwhl/blueprint//modules/nomad-redis"
  datacenter_name       = local.datacenter_name # Nomad datacenter name
  redis_version         = "7"                   # Redis version
  enable_ephemeral_disk = true                  # Enable Nomad ephemeral disk for the storing redis data temporarily. Cannot be used with host volumes.
  purge_on_destroy      = true                  # Purge Typesense job on destroy
}
```

### Persistent data

To enable persistent data, provide persistent volume configuration.

```hcl
module "redis" {
...
  persistent_config = {
    save_options = "60 1000" # dump the dataset to disk every 60 seconds if at least 1000 keys changed
  }
}
```

The data will be persisted to `/data`. One may mount host volumes to `/data`
for persisting typesense data.

```hcl
module "redis" {
...
  host_volume_config = {
    source = "host-volume-name"
    read_only = false
  }
}
```

Remember to update `/etc/nomad.d/nomad.hcl` configuration to create the host
volume. This should be under the `client` stanza.

```hcl
host_volume "host-volume-name" {
  path      = "/opt/typesense/data"
  read_only = false
}
```

Alternatively, you may use the `enable_ephemeral_disk` to enable ephemeral disk
for storing redis snapshots temporarily.

```hcl
module "redis" {
...
  enable_ephemeral_disk = true # Enable Nomad ephemeral disk for the storing redis data temporarily. Cannot be used with host volumes.
}
```