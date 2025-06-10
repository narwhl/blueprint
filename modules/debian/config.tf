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
    )
  ]
  packages = concat(
    var.default_packages,
    var.additional_packages,
    flatten(var.substrates.*.install.packages),
    var.expose_metrics ? ["prometheus-node-exporter"] : []
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
          # Adding 00 prefix to override the precedence of the default file
          path = "/etc/systemd/network/00-static.network"
          content = templatefile("${path.module}/templates/static.network.tftpl", {
            ip_address  = "${var.ip_address}/${local.subnet_bits}"
            gateway_ip  = var.gateway_ip
            nameservers = var.nameservers
          })
          tags    = "cloud-init"
          enabled = length(var.ip_address) > 0 && length(var.gateway_ip) > 0 && length(var.network) > 0
          owner   = "root"
          group   = "root"
          mode    = "0644"
          defer   = false
        }
      ],
      [
        for repository in data.http.gpg_keys : {
          path    = "/usr/share/keyrings/${repository.key}.gpg"
          content = repository.response_body
          owner   = "root"
          group   = "root"
          mode    = "0644"
          defer   = false
        }
      ],
      [
        for repository in distinct(
          concat(
            [
              "docker",
            ],
            flatten(var.substrates.*.install.repositories)
          )) : {
          path = "/etc/apt/sources.list.d/${repository}.sources"
          content = templatefile("${path.module}/templates/deb822.sources.tftpl", {
            source = merge(
              {
                for attr, val in jsondecode(data.http.upstream.response_body).repositories[repository].apt : attr => val if attr != "signing_key_url"
              },
              {
                key_file = format("/usr/share/keyrings/%s.gpg", repository)
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
    } if file.enabled == true && !startswith(file.content, "https://") && strcontains(file.tags, "cloud-init")
  ]
  directories = [for dir in flatten(var.substrates.*.directories) : dir if dir.enabled == true && strcontains(dir.tags, "cloud-init")]
  repositories = contains(flatten(var.substrates.*.install.repositories), "nvidia-container-toolkit") ? {
    "non-free.list" = {
      source = "deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware"
    }
  } : {}
}
