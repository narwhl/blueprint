data "cloudinit_config" "user_data" {
  gzip          = false
  base64_encode = var.base64_encode

  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content = join("\n", [
      "#cloud-config",
      yamlencode(
        merge(
          {
            users = local.users
            bootcmd = concat(
              [
                "hostnamectl set-hostname ${var.name}",
              ],
              length(var.network) > 0 ? [
                "sed -i -e 's/BOOTPROTO=dhcp/BOOTPROTO=static/g' /etc/sysconfig/network-scripts/ifcfg-eth0",
                "echo 'IPADDR=${var.ip_address}' >> /etc/sysconfig/network-scripts/ifcfg-eth0",
                "echo 'GATEWAY=${var.gateway_ip}' >> /etc/sysconfig/network-scripts/ifcfg-eth0",
                "echo 'NETMASK=${cidrnetmask(var.network)}' >> /etc/sysconfig/network-scripts/ifcfg-eth0",
                "echo '${local.dns_servers}' >> /etc/sysconfig/network-scripts/ifcfg-eth0",
                "systemctl restart NetworkManager",
              ] : [],
              [
                "dnf install -y gnupg ${contains(flatten(var.substrates.*.install.repositories), "nvidia-container-toolkit") ? "linux-headers-$(uname -r)" : ""}"
              ]
            )
            cloud_init_modules = concat(
              [
                "bootcmd",
                "write_files",
                "ssh", # regenerate ssh host keys
                "users-groups",
                "growpart", # expand root partition to fill disk
                "resizefs", # resize filesystem
              ],
              0 < length(var.disks) ? ["disk_setup", "fs_setup", "mounts"] : [],
              0 < length(var.ca_certs) ? ["ca_certs"] : []
            )
            cloud_config_modules = [
              "timezone",
              "runcmd"
            ]
            cloud_final_modules = [
              "package_update_upgrade_install",
              "scripts_user", # required for runcmd
              "power_state_change"
            ]
            hostname          = var.name
            manage_etc_hosts  = true
            preserve_hostname = false
            timezone          = var.timezone
            packages          = local.packages
            disk_setup        = local.disks
            fs_setup          = local.filesystems
            write_files       = local.files
            runcmd = concat(
              [for dir in local.directories : "mkdir -m ${dir.mode} -p ${dir.path}"],
              [for dir in local.directories : "chown -R ${dir.owner}:${dir.group} ${dir.path}"],
              var.startup_script.override_default ? [] : [
                "dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-${local.alma_major_version}-x86_64/pgdg-redhat-repo-latest.noarch.rpm",
                "dnf -qy module disable postgresql",
                "systemctl daemon-reload",
                "systemctl enable qemu-guest-agent docker --now",
                "systemctl enable --now fetch-remote-files.service"
              ],
              var.startup_script.inline,
              ["touch /etc/cloud/cloud-init.disabled"]
            )
            power_state = {
              delay = "now"
              mode  = "reboot"
            }
          },
          length(var.disks) > 0 ? {
            mounts = [
              for disk in var.disks : [
                disk.device_path,
                disk.mount_path,
              ]
            ]
          } : {},
          length(local.ca_certs.trusted) > 0 ? {
            ca_certs = local.ca_certs
          } : {}
        )
      )
    ])
  }
}
