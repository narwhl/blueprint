job "${job_name}" {
  datacenters = ["${datacenter_name}"]
  type        = "service"
  namespace   = "${namespace}"

  update {
    max_parallel     = 1
    min_healthy_time = "30s"
    healthy_deadline = "15m"
    auto_revert = true
  }

  group "matchbox" {

    network {
      mode = "host"
      port "http" {
        to     = 8080
        static = 8080
      }
      port "rpc" {
        to     = 8081
        static = 8081
      }
      port "dhcp" {
        static = 67
        to     = 67
      }
      port "dns" {
        static = 53
        to     = 53
      }
      port "tftp" {
        static = 69
        to     = 69
      }
    }

    task "dnsmasq" {

      driver = "docker"

      config {
        image    = "quay.io/poseidon/dnsmasq:${dnsmasq_version}"
        ports    = ["dhcp", "tftp", "dns"]

        mount {
          type   = "bind"
          source = "local/dnsmasq.conf"
          target = "/etc/dnsmasq.conf"
        }

        network_mode = "host"
        cap_add      = ["net_admin", "net_bind_service", "chown"]
        privileged   = true
      }

      template {
        data = <<-EOF
          keep-in-foreground
          dhcp-range=${dhcp_range_start},${dhcp_range_end},30m
          enable-tftp
          tftp-root=/var/lib/tftpboot

          # Legacy PXE
          dhcp-match=set:bios,option:client-arch,0
          dhcp-boot=tag:bios,undionly.kpxe

          # UEFI
          dhcp-match=set:efi32,option:client-arch,6
          dhcp-boot=tag:efi32,ipxe.efi
          dhcp-match=set:efibc,option:client-arch,7
          dhcp-boot=tag:efibc,ipxe.efi
          dhcp-match=set:efi64,option:client-arch,9
          dhcp-boot=tag:efi64,ipxe.efi

          # iPXE - chainload to matchbox ipxe boot script
          dhcp-userclass=set:ipxe,iPXE
          dhcp-boot=tag:ipxe,${matchbox_ipxe_url}

          log-queries
          log-dhcp
        EOF
        destination = "local/dnsmasq.conf"
        change_mode = "restart"
      }
    }

    task "matchbox" {

      driver = "docker"
      config {
        image    = "quay.io/poseidon/matchbox:${matchbox_version}"
        ports    = ["http", "rpc"]
        args = [
          "-address=0.0.0.0:8080",
          "-rpc-address=0.0.0.0:8081",
          "-log-level=debug",
        ]

        ${mounts}

        mount {
          type   = "bind"
          source = "local/server.crt"
          target = "/etc/matchbox/server.crt"
        }

        mount {
          type   = "bind"
          source = "local/server.key"
          target = "/etc/matchbox/server.key"
        }

        mount {
          type   = "bind"
          source = "local/ca.crt"
          target = "/etc/matchbox/ca.crt"
        }
      }

      template {
        data = <<-EOF
${server_cert_pem}
        EOF
        destination = "local/server.crt"
        change_mode = "restart"
      }

      template {
        data = <<-EOF
${server_key_pem}
        EOF
        destination = "local/server.key"
        change_mode = "restart"
      }

      template {
        data = <<-EOF
${root_ca_cert_pem}
        EOF
        destination = "local/ca.crt"
        change_mode = "restart"
      }

      ${artifacts}
    }
  }
}
