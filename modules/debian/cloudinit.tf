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
            system_info = {
              apt_get_command = [
                "apt-get",
                "--option=Dpkg::Options::=--force-confold",
                "--option=Dpkg::options::=--force-unsafe-io",
                "--assume-yes",
                "--quiet",
                "--no-install-recommends",
              ]
            }
            apt = {
              preserve_sources_list = true
              sources               = local.repositories
            }
            users = local.users
            bootcmd = [
              "apt-get update && apt-get install -y gnupg ${contains(flatten(var.substrates.*.install.repositories), "nvidia-container-toolkit") ? "linux-headers-$(uname -r)" : ""}"
            ]
            cloud_init_modules = concat(
              [
                "bootcmd",
                "write_files",
                "set_hostname",
                "ssh", # regenerate ssh host keys
                "users-groups",
                "growpart", # expand root partition to fill disk
                "resizefs", # resize filesystem
              ],
              0 < length(var.disks) ? ["disk_setup", "fs_setup", "mounts"] : [],
              0 < length(var.ca_certs) ? ["ca_certs"] : []
            )
            cloud_config_modules = [
              "apt_configure",
              "timezone",
              "update_etc_hosts",
              "runcmd"
            ]
            cloud_final_modules = [
              "package_update_upgrade_install",
              "scripts_user", # required for runcmd
              "power_state_change",
              "write-files-deferred",
            ]
            hostname         = var.name
            manage_etc_hosts = true
            timezone         = var.timezone
            packages         = local.packages
            ca_certs         = local.ca_certs
            disk_setup       = local.disks
            fs_setup         = local.filesystems
            write_files      = local.files
            mounts = [
              for disk in var.disks : [
                disk.device_path,
                disk.mount_path,
              ]
            ]
            runcmd = concat(
              var.startup_script.override_default ? [] : [
                "systemctl daemon-reload",
                "systemctl enable qemu-guest-agent --now",
                "systemctl restart --no-block systemd-resolved systemd-networkd",
              ],
              var.startup_script.inline
            )
          },
          contains(flatten(var.substrates.*.install.repositories), "nvidia-container-toolkit") ? {
            power_state = {
              delay = "now"
              mode  = "reboot"
            }
          } : {}
        )
      )
    ])
  }
}
