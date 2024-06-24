# Terraform module for running Nomad on Flatcar/ Debian

## Usage

Include output `manifest` in `substrates` of `debian` or `flatcar` module.

```terraform
module "nomad" {
    source = "github.com/narwhl/blueprint//modules/nomad"
    datacenter_name = "dc1"
    role            = "server"
}

# Alternatively, you may use Flatcar module
module "debian" {
  source = "github.com/narwhl/blueprint//modules/debian"
  name   = "debian-vm"
  substrates = [
    module.nomad.manifest,
    ...
  ]
  ...
}
```

### Configuration

`supplychain`: Address pointing to upstream dependency JSON metadata file. This should leave as default unless package
versions need to be customized. Defaults to `https://artifact.narwhl.dev/upstream/current.json`.

`data_dir`: The directory to store Nomad data. Defaults to `/opt/nomad`.

`datacenter_name`: The name of the Nomad datacenter to use.

`log_level`: The log level to use. Defaults to `INFO`.

`role`: The role of the Nomad node to run, can be `client` or `server`. Defaults to `server`.

`bootstrap_expect`: Number of nomad instance connection expected to form the cluster. Must be an odd integer.
Defaults to `1`.

`gossip_key`: The gossip encryption key. Gossip encryption is not enforced when leaving this empty.

`tls`: The TLS certificate configuration. TLS is not enforced when leaving this empty.

`host_volume`: A map of host volume configurations. The key is the host volume name and the value is an object with
the `path` and `read_only` fields. The `path` field is the path on the host where the volume is mounted and the
`read_only` field is a boolean indicating whether the volume is read-only.
