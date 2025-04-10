resource "random_bytes" "secret" {
  length = 32
}

resource "nomad_variable" "secrets" {
  path = "nomad/jobs/${var.job_name}"
  items = {
    tsig_secret_key   = random_bytes.secret.base64
    tailscale_authkey = var.tailscale_authkey
  }
}

resource "nomad_job" "bind" {
  jobspec = templatefile("${path.module}/templates/bind.nomad.hcl.tftpl", {
    job_name             = var.job_name
    datacenter_name      = var.datacenter_name
    namespace            = var.namespace
    bind_version         = var.bind_version
    tailscale_version    = var.tailscale_version
    zones                = var.zones
    upstream_nameservers = var.upstream_nameservers
    resources            = var.resources
    split_dns_vars = yamlencode({
      digest = base64encode("${var.tailscale_oauth_client_id}:${var.tailscale_oauth_client_secret}")
      domain = ".internal"
    })
    split_dns_provisioner = file("${path.module}/templates/playbook.yml")
    secret_key = templatefile("${path.module}/templates/named.conf.key.tftpl", {
      job_name  = var.job_name
      name      = var.tsig_key_name
      algorithm = var.tsig_algorithm
    })
    zone_files = [for z in var.zones : {
      name = z
      content = templatefile(
        "${path.module}/templates/zonefile.tftpl",
        {
          zone = z
        }
      )
    }]
    config = templatefile("${path.module}/templates/named.conf.tftpl", {
      zones                = var.zones
      upstream_nameservers = var.upstream_nameservers
    })
  })
  purge_on_destroy = var.purge_on_destroy
}
