locals {
  systemd_units = [
    {
      name    = "authenticate-tailscale.service"
      content = file("${path.module}/templates/authenticate-tailscale.service")
    }
  ]
  directories = [
    {
      path  = "/var/lib/tailscale"
      owner = "root"
      group = "root"
    },
  ]
  pkgs = {
    for pkg in ["tailscale"] : pkg => jsondecode(data.http.upstream.response_body).syspkgs[pkg]
  }
}

resource "terraform_data" "manifest" {
  input = {
    users       = []
    directories = local.directories
    packages    = keys(local.pkgs)
    files = concat(
      [
        for pkg in keys(local.pkgs) : {
          path = format(
            "/etc/extensions/${pkg}-%s-x86-64.raw",
            local.pkgs[pkg].version
          )
          tags    = "ignition"
          content = format("https://artifact.narwhl.dev/sysext/%s-%s-x86-64.raw", pkg, local.pkgs[pkg].version)
          enabled = true
        }
      ],
      [
        for pkg in keys(local.pkgs) : {
          path = "/etc/sysupdate.${pkg}.d/${pkg}.conf"
          content = templatefile(
            "${path.module}/templates/update.conf.tftpl",
            {
              url     = "https://artifact.narwhl.dev/sysext"
              package = pkg
            }
          )
          tags    = "ignition"
          enabled = true
        }
      ],
      [
        {
          path    = "/etc/default/tailscaled"
          content = ""
          tags    = "ignition"
          enabled = true
        }
      ]
    )
    install = {
      packages = [
        "tailscale"
      ]
      repositories = [
        "tailscale",
      ]
      systemd_units = local.systemd_units
    }
  }
}