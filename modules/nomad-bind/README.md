# Terraform module for running Bind DNS server on Nomad

## Usage

```hcl
module "dns" {
  source               = "registry.narwhl.workers.dev/stack/bind/nomad"
  upstream_nameservers = ["1.1.1.1"]
  zones                = ["example.internal"]
  bind_version         = "9.21"
  tailscale_auth_key   = "tskey-1234567890abcdef"
}
```

## Argument Reference

- `job_name`: `(string: <optional>)` - Name of the Nomad job.

- `datacenter_name`: `(string: <optional>)` - Datacenter to deploy the job to.

- `namespace`: `(string: <optional>)` - Namespace to deploy the job to.

- `bind_version`: `(string: <required>)` - Version of Bind to deploy.

- `upstream_nameservers`: `(list(string): <optional>)` - List of upstream nameservers to forward queries to.

- `zones`: `(list(string): <required>)` - List of zones to configure.

- `tsig_algorithm`: `(string: "hmac-sha256")` - Algorithm to use for TSIG.

- `tsig_key_name`: `(string: "tsig")` - Name of the TSIG key to use for zone updates.

- `tailscale_version`: `(string: "stable")` - Version of Tailscale to deploy.

- `tailscale_oauth_client_id`: `(string: <required>)` - Tailscale OAuth client ID.

- `tailscale_oauth_client_secret`: `(string: <required>)` - Tailscale OAuth client secret.

- `tailscale_auth_key`: `(string: <required>)` - Tailscale authentication key.

- `resources`: `(object: <optional>)` - Resources to allocate to the job.

- `purge_on_destroy`: `(bool: false)` - Whether to purge the job on destroy.

## Attributes Reference

- `tsig_secret_key`: `(string)` - TSIG secret key for secure zone updates.
