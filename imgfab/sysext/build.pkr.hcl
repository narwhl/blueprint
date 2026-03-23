build {
  name = "package"
  sources = [
    "source.null.cloudflared",
    "source.null.cni-plugins",
    "source.null.coredns",
    "source.null.consul-template",
    "source.null.consul",
    "source.null.firecracker",
    "source.null.lego",
    "source.null.nomad",
    "source.null.node-exporter",
    "source.null.alloy",
    "source.null.step-ca",
    "source.null.tailscale",
    "source.null.vault",
  ]

  provisioner "shell-local" {
    only = ["null.cloudflared"]
    inline = concat(
      local.templates["cloudflared"],
      [
        "curl -LO ${local.syspkgs.cloudflared.pkg_url}",
        "mv ${local.syspkgs.cloudflared.filename} cloudflared-${local.syspkgs.cloudflared.version}-amd64/usr/bin/cloudflared",
        "chmod +x cloudflared-${local.syspkgs.cloudflared.version}-amd64/usr/bin/cloudflared",
      ],
      [
        "mksquashfs cloudflared-${local.syspkgs.cloudflared.version}-amd64 cloudflared-${local.syspkgs.cloudflared.version}-x86-64.raw",
        "rm -rf cloudflared-${local.syspkgs.cloudflared.version}-amd64",
      ]
    )
  }

  provisioner "shell-local" {
    only = ["null.cni-plugins"]
    inline = concat(
      local.templates["cni-plugins"],
      [
        "curl -LO ${local.syspkgs["cni-plugins"].pkg_url}",
        "tar -C cni-plugins-${local.syspkgs["cni-plugins"].version}-amd64/usr/lib/cni -xzf ${local.syspkgs["cni-plugins"].filename}",
      ],
      [
        "mksquashfs cni-plugins-${local.syspkgs["cni-plugins"].version}-amd64 cni-plugins-${local.syspkgs["cni-plugins"].version}-x86-64.raw",
        "rm -rf cni-plugins-${local.syspkgs["cni-plugins"].version}-amd64 ${local.syspkgs["cni-plugins"].filename}",
      ]
    )
  }

  provisioner "shell-local" {
    only = ["null.consul-template"]
    inline = concat(
      local.templates["consul-template"],
      [
        "curl -LO ${local.syspkgs["consul-template"].pkg_url}",
        "unzip ${local.syspkgs["consul-template"].filename} -d consul-template-${local.syspkgs["consul-template"].version}-amd64/usr/bin",
      ],
      [
        for step in local.copy_service_unit_steps : format(step, "consul-template", local.syspkgs["consul-template"].version)
      ],
      [
        "mksquashfs consul-template-${local.syspkgs["consul-template"].version}-amd64 consul-template-${local.syspkgs["consul-template"].version}-x86-64.raw",
        "rm -rf consul-template-${local.syspkgs["consul-template"].version}-amd64 ${local.syspkgs["consul-template"].filename}",
      ]
    )
  }

  provisioner "shell-local" {
    only = ["null.consul"]
    inline = concat(
      local.templates.consul,
      [
        "curl -LO ${local.syspkgs.consul.pkg_url}",
        "unzip ${local.syspkgs.consul.filename} -d consul-${local.syspkgs.consul.version}-amd64/usr/bin",
      ],
      [
        for step in local.copy_service_unit_steps : format(step, "consul", local.syspkgs.consul.version)
      ],
      [
        "mksquashfs consul-${local.syspkgs.consul.version}-amd64 consul-${local.syspkgs.consul.version}-x86-64.raw",
        "rm -rf consul-${local.syspkgs.consul.version}-amd64 ${local.syspkgs.consul.filename}",
      ]
    )
  }

  provisioner "shell-local" {
    only = ["null.coredns"]
    inline = concat(
      local.templates.coredns,
      [
        "curl -LO ${local.syspkgs.coredns.pkg_url}",
        "tar -C coredns-${local.syspkgs.coredns.version}-amd64/usr/bin -xzf ${local.syspkgs.coredns.filename}"
      ],
      [
        for step in local.copy_service_unit_steps : format(step, "coredns", local.syspkgs.coredns.version)
      ],
      [
        "mksquashfs coredns-${local.syspkgs.coredns.version}-amd64 coredns-${local.syspkgs.coredns.version}-x86-64.raw",
        "rm -rf coredns-${local.syspkgs.coredns.version}-amd64 ${local.syspkgs.coredns.filename}",
      ]
    )
  }

  provisioner "shell-local" {
    only = ["null.firecracker"]
    inline = concat(
      local.templates.firecracker,
      [
        "curl -LO ${local.syspkgs.firecracker.pkg_url}",
        "tar -C firecracker-${local.syspkgs.firecracker.version}-amd64/usr/bin -xzf ${local.syspkgs.firecracker.filename} --strip-components=1 release-v${local.syspkgs.firecracker.version}-x86_64/firecracker-v${local.syspkgs.firecracker.version}-x86_64",
        "mv firecracker-${local.syspkgs.firecracker.version}-amd64/usr/bin/firecracker-v${local.syspkgs.firecracker.version}-x86_64 firecracker-${local.syspkgs.firecracker.version}-amd64/usr/bin/firecracker",
      ],
      [
        "mksquashfs firecracker-${local.syspkgs.firecracker.version}-amd64 firecracker-${local.syspkgs.firecracker.version}-x86-64.raw",
        "rm -rf firecracker-${local.syspkgs.firecracker.version}-amd64 ${local.syspkgs.firecracker.filename}",
      ]
    )
  }

  provisioner "shell-local" {
    only = ["null.lego"]
    inline = concat(
      local.templates.lego,
      [
        "curl -LO ${local.syspkgs.lego.pkg_url}",
        "tar -C lego-${local.syspkgs.lego.version}-amd64/usr/bin -xzf ${local.syspkgs.lego.filename} lego",
      ],
      [
        "mksquashfs lego-${local.syspkgs.lego.version}-amd64 lego-${local.syspkgs.lego.version}-x86-64.raw",
        "rm -rf lego-${local.syspkgs.lego.version}-amd64 ${local.syspkgs.lego.filename}",
      ]
    )
  }

  provisioner "shell-local" {
    only = ["null.nomad"]
    inline = concat(
      local.templates.nomad,
      [
        "curl -LO ${local.syspkgs.nomad.pkg_url}",
        "unzip ${local.syspkgs.nomad.filename} -d nomad-${local.syspkgs.nomad.version}-amd64/usr/bin",
      ],
      [
        for step in local.copy_service_unit_steps : format(step, "nomad", local.syspkgs.nomad.version)
      ],
      [
        "mksquashfs nomad-${local.syspkgs.nomad.version}-amd64 nomad-${local.syspkgs.nomad.version}-x86-64.raw",
        "rm -rf nomad-${local.syspkgs.nomad.version}-amd64 ${local.syspkgs.nomad.filename}",
      ]
    )
  }

  provisioner "shell-local" {
    only = ["null.node-exporter"]
    inline = concat(
      local.templates["node-exporter"],
      [
        "curl -LO ${local.syspkgs["node-exporter"].pkg_url}",
        "tar -C node-exporter-${local.syspkgs["node-exporter"].version}-amd64/usr/local/sbin -xzf ${local.syspkgs["node-exporter"].filename} --strip-components=1 ${trimsuffix(local.syspkgs["node-exporter"].filename, ".tar.gz")}/node_exporter",
        "cp templates/node-exporter.socket node-exporter-${local.syspkgs["node-exporter"].version}-amd64/usr/lib/systemd/system/node-exporter.socket"
      ],
      [
        for step in local.copy_service_unit_steps : format(step, "node-exporter", local.syspkgs["node-exporter"].version)
      ],
      [
        "mksquashfs node-exporter-${local.syspkgs["node-exporter"].version}-amd64 node-exporter-${local.syspkgs["node-exporter"].version}-x86-64.raw",
        "rm -rf node-exporter-${local.syspkgs["node-exporter"].version}-amd64 ${local.syspkgs["node-exporter"].filename}",
      ]
    )
  }

  provisioner "shell-local" {
    only = ["null.alloy"]
    inline = concat(
      local.templates.alloy,
      [
        "curl -LO ${local.syspkgs.alloy.pkg_url}",
        "unzip ${local.syspkgs.alloy.filename} -d alloy-${local.syspkgs.alloy.version}-amd64/usr/bin",
        "mv alloy-${local.syspkgs.alloy.version}-amd64/usr/bin/${trimsuffix(local.syspkgs["alloy"].filename, ".zip")} alloy-${local.syspkgs.alloy.version}-amd64/usr/bin/alloy"
      ],
      [
        for step in local.copy_service_unit_steps : format(step, "alloy", local.syspkgs["alloy"].version)
      ],
      [
        "mksquashfs alloy-${local.syspkgs.alloy.version}-amd64 alloy-${local.syspkgs.alloy.version}-x86-64.raw",
        "rm -rf alloy-${local.syspkgs.alloy.version}-amd64 ${local.syspkgs.alloy.filename}",
      ]
    )
  }

  provisioner "shell-local" {
    only = ["null.step-ca"]
    inline = concat(
      local.templates["step-ca"],
      [
        "curl -LO ${local.syspkgs["step-ca"].pkg_url}",
        "tar -C step-ca-${local.syspkgs["step-ca"].version}-amd64/usr/bin -xzf ${local.syspkgs["step-ca"].filename} step-ca",
        "curl -LO ${local.syspkgs["step-cli"].pkg_url}",
        "tar -C step-ca-${local.syspkgs["step-ca"].version}-amd64/usr/bin -xzf ${local.syspkgs["step-cli"].filename} --strip-components=2 step_${local.syspkgs["step-cli"].version}/bin/step",
      ],
      [
        for step in local.copy_service_unit_steps : format(step, "step-ca", local.syspkgs["step-ca"].version)
      ],
      [
        "mksquashfs step-ca-${local.syspkgs["step-ca"].version}-amd64 step-ca-${local.syspkgs["step-ca"].version}-x86-64.raw",
        "rm -rf step-ca-${local.syspkgs["step-ca"].version}-amd64 ${local.syspkgs["step-ca"].filename} ${local.syspkgs["step-cli"].filename}",
      ]
    )
  }

  provisioner "shell-local" {
    only = ["null.tailscale"]
    inline = concat(
      local.templates.tailscale,
      [
        "curl -LO ${local.syspkgs.tailscale.pkg_url}",
        "tar -C tailscale-${local.syspkgs.tailscale.version}-amd64/usr/local/sbin -xzf ${local.syspkgs.tailscale.filename} --strip-components=1 tailscale_${local.syspkgs.tailscale.version}_amd64/tailscaled",
        "tar -C tailscale-${local.syspkgs.tailscale.version}-amd64/usr/bin -xzf ${local.syspkgs.tailscale.filename} --strip-components=1 tailscale_${local.syspkgs.tailscale.version}_amd64/tailscale",
      ],
      [
        "cp templates/tailscaled.service tailscale-${local.syspkgs.tailscale.version}-amd64/usr/lib/systemd/system/tailscaled.service",
        "cp templates/uphold.conf.tpl tailscale-${local.syspkgs.tailscale.version}-amd64/usr/lib/systemd/system/multi-user.target.d/10-tailscaled.conf",
        "echo -n 'tailscaled.service' >> tailscale-${local.syspkgs.tailscale.version}-amd64/usr/lib/systemd/system/multi-user.target.d/10-tailscaled.conf",
      ],
      [
        "mksquashfs tailscale-${local.syspkgs.tailscale.version}-amd64 tailscale-${local.syspkgs.tailscale.version}-x86-64.raw",
        "rm -rf tailscale-${local.syspkgs.tailscale.version}-amd64 ${local.syspkgs.tailscale.filename}",
      ]
    )
  }

  provisioner "shell-local" {
    only = ["null.vault"]
    inline = concat(
      local.templates.vault,
      [
        "curl -LO ${local.syspkgs.vault.pkg_url}",
        "unzip ${local.syspkgs.vault.filename} -d vault-${local.syspkgs.vault.version}-amd64/usr/bin",
      ],
      [
        for step in local.copy_service_unit_steps : format(step, "vault", local.syspkgs.vault.version)
      ],
      [
        "mksquashfs vault-${local.syspkgs.vault.version}-amd64 vault-${local.syspkgs.vault.version}-x86-64.raw",
        "rm -rf vault-${local.syspkgs.vault.version}-amd64 ${local.syspkgs.vault.filename} ${local.syspkgs.lego.filename}",
      ]
    )
  }

  post-processor "shell-local" {
    except = []
    inline = [
      "rclone copy -v ${source.name}-${local.syspkgs[source.name].version}-x86-64.raw r2:artifact/sysext/",
    ]
    environment_vars = local.rclone_s3_config
  }
}

build {
  name = "checksum"
  sources = [
    "source.null.checksum",
  ]

  post-processor "shell-local" {
    inline = [
      "rclone copy r2:artifact/sysext . --include '*.raw'",
      "sha256sum *.raw | tee SHA256SUMS",
      "rclone copy SHA256SUMS r2:artifact/sysext/",
    ]
    environment_vars = local.rclone_s3_config
  }
}
