resource "terraform_data" "manifest" {
  input = {
    directories = local.directories
    packages    = keys(local.pkgs)
    users       = local.users
    files = concat(
      local.configs,
      [
        for pkg in keys(local.pkgs) : {
          path = format(
            "/etc/extensions/${pkg}-%s-x86-64.raw",
            local.pkgs[pkg].version
          )
          content = format("https://artifact.narwhl.dev/sysext/%s-%s-x86-64.raw", pkg, local.pkgs[pkg].version)
          enabled = true
          tags    = "ignition"
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
          enabled = true
          tags    = "ignition"
        }
      ],
      [
        for key, item in var.tls.enable && var.tls.ca_cert != null && var.tls.server_cert != null && var.tls.server_key != null ? {
          ca_cert = var.tls.ca_cert
          server_cert = var.tls.server_cert
          server_key = var.tls.server_key
        } : {} : {
          path    = item.path
          content = item.content
          enabled = var.tls.enable && length(item.content) > 0
          tags    = "cloud-init,ignition"
        }
      ]
    )
    install = {
      systemd_units = local.systemd_units
      repositories  = local.repositories
      packages      = local.packages
    }
  }
}
