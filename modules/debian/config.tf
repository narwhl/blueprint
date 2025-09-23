data "http" "upstream" {
  url = var.supplychain
}

data "http" "gpg_keys" {
  for_each = {
    for repository in distinct(
      concat(
        [
          "docker",
        ],
        flatten(var.substrates.*.install.repositories)
      )
    ) : repository => jsondecode(data.http.upstream.response_body).repositories[repository].apt.signing_key_url
  }
  url = each.value
}

data "http" "ca_certs" {
  for_each = {
    for cert in var.ca_certs : cert => cert if startswith(cert, "http")
  }
  url = each.value
}

data "http" "ssh_keys_import" {
  count = length(var.ssh_keys_import)
  url   = var.ssh_keys_import[count.index]
}

data "external" "openssl" {
  count = 0 < length(var.password) ? 1 : 0
  program = [
    "sh",
    "-c",
    "jq -r '.password' | openssl passwd -6 -stdin | jq --raw-input '{\"password_hash\": .}'"
  ]
  query = {
    password = var.password
  }
}
locals {
  alloy       = jsondecode(data.http.upstream.response_body).syspkgs["alloy"]
  subnet_bits = 0 < length(var.network) ? split("/", var.network)[1] : "24"
}

locals {
  users = [
    merge(
      {
        name        = var.username
        sudo        = "ALL=(ALL) NOPASSWD:ALL"
        shell       = "/bin/bash"
        groups      = ["adm", "netdev", "plugdev", "sudo", "docker"]
        lock_passwd = true
        ssh_authorized_keys = distinct(concat(
          var.ssh_authorized_keys,
          compact(flatten([
            for v in data.http.ssh_keys_import : split("\n", v.response_body)
          ]))
        ))
      },
      0 < length(var.password) ? {
        passwd      = data.external.openssl[0].result.password_hash
        lock_passwd = false
      } : {}
    ),
    {
      name           = "alloy"
      shell          = "/bin/false"
      no_create_home = true
      system         = true
      lock_passwd    = true
    }
  ]
  packages = concat(
    var.default_packages,
    local.additional_packages,
    flatten(var.substrates.*.install.packages),
  )
  ca_certs = {
    trusted = [
      for index, cert in var.ca_certs : startswith(cert, "http") ? data.http.ca_certs["cert${index}"].response_body : cert
    ]
  }
  disks = {
    for disk in var.disks : disk.device_path => {
      table_type = "gpt"
      layout     = true
      overwrite  = true
    }
  }
  filesystems = [
    for disk in var.disks : {
      label      = disk.label
      filesystem = "ext4"
      device     = disk.device_path
      partition  = "auto"
    }
  ]
  files = [
    for file in concat(
      [
        {
          path    = "/etc/systemd/system/docker.service.d/override.conf"
          content = file("${path.module}/templates/docker-service-override.conf.tftpl")
          enabled = var.expose_docker_socket
          tags    = "cloud-init"
          owner   = "root"
          group   = "root"
          mode    = "0644"
          defer   = false
        },
        {
          path = "/etc/systemd/system/getty@tty1.service.d/override.conf"
          content = templatefile(
            "${path.module}/templates/getty-service-override.conf.tftpl",
            {
              username = var.username
            }
          )
          enabled = var.autologin
          tags    = "cloud-init"
          owner   = "root"
          group   = "root"
          mode    = "0644"
          defer   = false
        },
        {
          path = "/etc/systemd/resolved.conf"
          content = templatefile("${path.module}/templates/resolved.conf.tftpl", {
            nameservers = var.nameservers
          })
          enabled = !contains(flatten(var.substrates.*.install.packages), "consul")
          tags    = "cloud-init"
          owner   = "root"
          group   = "root"
          mode    = "0644"
          defer   = false
        },
        {
          # Adding 00 prefix to override the precedence of the default file
          path = "/etc/systemd/network/00-default.network"
          content = templatefile("${path.module}/templates/default.network.tftpl", {
            ip_address  = "${var.ip_address}/${local.subnet_bits}"
            gateway_ip  = var.gateway_ip
            nameservers = var.nameservers
          })
          tags    = "cloud-init"
          enabled = true
          owner   = "root"
          group   = "root"
          mode    = "0644"
          defer   = false
        },
        {
          path    = "/etc/default/alloy"
          mode    = "0644"
          owner   = "alloy"
          group   = "alloy"
          defer   = false
          enabled = true
          tags    = "cloud-init"
          content = <<-EOF
          ## Path:
          ## Description: Grafana Alloy settings
          ## Type:        string
          ## Default:     ""
          ## ServiceRestart: alloy
          #
          # Command line options for alloy
          #
          # The configuration file holding the Grafana Alloy configuration.
          CONFIG_FILE="/etc/alloy"

          # User-defined arguments to pass to the run command.
          CUSTOM_ARGS=""

          # Restart on system upgrade. Defaults to true.
          RESTART_ON_UPGRADE=true
        EOF
        },
        {
          path    = "/etc/alloy/config.alloy"
          mode    = "0644"
          owner   = "alloy"
          group   = "alloy"
          enabled = true
          tags    = "cloud-init"
          defer   = false
          content = var.telemetry.enabled ? templatefile("${path.module}/templates/config.alloy.tftpl", {
            loki_addr       = var.telemetry.loki_addr
            prometheus_addr = var.telemetry.prometheus_addr
          }) : ""
        },
      ],
      [
        for repository in distinct(
          concat(
            [
              "docker",
            ],
            flatten(var.substrates.*.install.repositories)
          )) : {
          enabled = true
          tags    = "cloud-init"
          path    = "/etc/apt/sources.list.d/${repository}.sources.tmp"
          content = templatefile("${path.module}/templates/deb822.sources.tftpl", {
            source = merge(
              {
                for attr, val in jsondecode(data.http.upstream.response_body).repositories[repository].apt : attr => val if attr != "signing_key_url"
              },
              {
                key_file = indent(2, data.http.gpg_keys[repository].response_body)
              }
            )
          })
          owner = "root"
          group = "root"
          mode  = "0644"
          defer = false
        }
      ],
      flatten(var.substrates.*.files)
      ) : {
      encoding    = "b64"
      content     = base64encode(file.content)
      path        = file.path
      owner       = format("%s:%s", file.owner, file.group)
      permissions = length(file.mode) < 4 ? "0${file.mode}" : file.mode
      defer       = file.defer # ensure users, packages are created before writing extra files
    } if file.enabled == true && strcontains(file.tags, "cloud-init") && !startswith(file.content, "https://")
  ]
  remote_files = [
    for file in concat(
      [
        {
          path = format(
            "/etc/extensions/alloy-%s-x86-64.raw",
            local.alloy.version
          )
          content = format("https://artifact.narwhl.dev/sysext/alloy-%s-x86-64.raw", local.alloy.version)
          enabled = true
          defer   = false
          mode    = "0644"
          owner   = "root"
          group   = "root"
          tags    = "cloud-init"
        }
      ],
      flatten(var.substrates.*.files)
      ) : {
      path = file.path
      source = {
        uri = file.content
      }
      owner       = format("%s:%s", file.owner, file.group)
      permissions = length(file.mode) < 4 ? "0${file.mode}" : file.mode
      defer       = file.defer # ensure users, packages are created before writing extra files
    } if file.enabled == true && strcontains(file.tags, "cloud-init") && startswith(file.content, "http")
  ]
  directories = [for dir in flatten(var.substrates.*.directories) : dir if dir.enabled == true && strcontains(dir.tags, "cloud-init")]
  repositories = contains(flatten(var.substrates.*.install.repositories), "nvidia-container-toolkit") ? {
    "non-free.list" = {
      source = "deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware"
    }
  } : {}
}
