data "http" "upstream" {
  url = var.supplychain
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

data "http" "repositories" {
  for_each = local.repositories
  url      = each.value
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
  alma_major_version = split(".", jsondecode(data.http.upstream.response_body).distros.alma.version)[0]
  subnet_bits        = 0 < length(var.network) ? split("/", var.network)[1] : "24"
  repositories = {
    for repository in distinct(
      concat(
        [
          "docker",
        ],
        flatten(var.substrates.*.install.repositories)
      )
    ) : "${repository}.repo" => jsondecode(data.http.upstream.response_body).repositories[repository].dnf.source
  }
}

locals {
  alloy = jsondecode(data.http.upstream.response_body).syspkgs["alloy"]
  remote_files = concat(
    [
      for file in flatten(var.substrates.*.files) :
      {
        url   = file.content
        path  = file.path
        owner = format("%s:%s", file.owner, file.group)
        mode  = length(file.mode) < 4 ? "0${file.mode}" : file.mode
      } if file.enabled == true && startswith(file.content, "https://")
    ],
    [
      {
        url   = format("https://artifact.narwhl.dev/sysext/alloy-%s-x86-64.raw", local.alloy.version)
        path  = format("/etc/extensions/alloy-%s-x86-64.raw", local.alloy.version)
        owner = "root:root"
        mode  = "0644"
      }
    ]
  )
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
    flatten(var.substrates.*.install.packages)
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
          path = "/opt/bin/fetch-remote-files.sh"
          content = templatefile("${path.module}/templates/fetch-remote-files.sh.tftpl", {
            paths  = join("\n", local.remote_files.*.path)
            urls   = join("\n", local.remote_files.*.url)
            owners = join("\n", local.remote_files.*.owner)
            modes  = join("\n", local.remote_files.*.mode)
          })
          owner   = "root"
          group   = "root"
          mode    = "0755"
          enabled = true
          tags    = "cloud-init"
        },
        {
          path    = "/etc/systemd/system/docker.service.d/override.conf"
          content = file("${path.module}/templates/docker-service-override.conf.tftpl")
          enabled = var.expose_docker_socket
          owner   = "root"
          group   = "root"
          mode    = "0644"
          tags    = "cloud-init"
        },
        {
          path = "/etc/systemd/system/getty@tty1.service.d/override.conf"
          content = templatefile(
            "${path.module}/templates/getty-service-override.conf.tftpl",
            {
              username = var.username
            }
          )
          owner   = "root"
          group   = "root"
          enabled = var.autologin
          mode    = "0644"
          tags    = "cloud-init"
        },
        {
          path    = "/etc/yum.repos.d/mongo.repo"
          content = <<-EOF
            [mongodb-org-7.0]
            name=MongoDB Repository
            baseurl=https://repo.mongodb.org/yum/redhat/${local.alma_major_version}/mongodb-org/7.0/x86_64/
            gpgcheck=1
            enabled=1
            gpgkey=https://pgp.mongodb.com/server-7.0.asc
          EOF
          owner   = "root"
          group   = "root"
          enabled = true
          mode    = "0644"
          tags    = "cloud-init"
        },
        {
          path    = "/etc/default/alloy"
          mode    = "0644"
          owner   = "alloy"
          group   = "alloy"
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
          content = var.telemetry.enabled ? templatefile("${path.module}/templates/config.alloy.tftpl", {
            loki_addr       = var.telemetry.loki_addr
            prometheus_addr = var.telemetry.prometheus_addr
          }) : ""
        },
        {
          path = "/etc/systemd/system/fetch-remote-files.service"
          content = <<-EOF
          [Unit]
          Description=Adhoc remote files fetching during provisioning
          After=network-online.target
          Wants=network-online.target

          [Service]
          Type=oneshot
          ExecStart=/opt/bin/fetch-remote-files.sh
          User=root
          Group=root

          # Keep the service in a 'failed' state if the script exits with an error.
          RemainAfterExit=no

          [Install]
          WantedBy=multi-user.target
          EOF
        }
      ],
      [
        for repo in keys(data.http.repositories) : {
          path    = "/etc/yum.repos.d/${repo}"
          content = data.http.repositories[repo].response_body
          enabled = true
          owner   = "root"
          group   = "root"
          mode    = "0644"
          tags    = "cloud-init"
        }
      ],
      flatten(var.substrates.*.files)
      ) : {
      encoding    = "b64"
      content     = base64encode(file.content)
      path        = file.path
      owner       = format("%s:%s", file.owner, file.group)
      permissions = length(file.mode) < 4 ? "0${file.mode}" : file.mode
    } if file.enabled == true && !startswith(file.content, "https://") && strcontains(file.tags, "cloud-init")
  ]
  directories = [for dir in flatten(var.substrates.*.directories) : dir if dir.enabled == true && strcontains(dir.tags, "cloud-init")]
  dns_servers = join("\n", [
    for nameserver in distinct(var.nameservers) : "DNS${index(distinct(var.nameservers), nameserver) + 1}=${nameserver}"
  ])
}
