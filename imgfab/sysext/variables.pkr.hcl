variable "cf_r2_endpoint" {
  type    = string
  default = env("CF_R2_ENDPOINT_URL")
}

variable "cf_r2_access_key_id" {
  type      = string
  sensitive = true
  default   = env("CF_R2_ACCESS_KEY_ID")
}

variable "cf_r2_secret_access_key" {
  type      = string
  sensitive = true
  default   = env("CF_R2_SECRET_ACCESS_KEY")
}

data "http" "supplychain" {
  url = "https://artifact.narwhl.dev/upstream/current.json"
}

locals {
  syspkgs            = jsondecode(data.http.supplychain.body).syspkgs
  default_sysext_dir = ["usr/bin", "usr/local/sbin", "usr/lib/systemd/system/multi-user.target.d", "usr/lib/extension-release.d"]
}

locals {
  rclone_s3_config = [
    "RCLONE_CONFIG_R2_TYPE=s3",
    "RCLONE_CONFIG_R2_PROVIDER=Cloudflare",
    "RCLONE_CONFIG_R2_ENDPOINT=${var.cf_r2_endpoint}",
    "RCLONE_CONFIG_R2_ACCESS_KEY_ID=${var.cf_r2_access_key_id}",
    "RCLONE_CONFIG_R2_SECRET_ACCESS_KEY=${var.cf_r2_secret_access_key}",
    "RCLONE_S3_NO_CHECK_BUCKET=true"
  ]
  copy_service_unit_steps = [
    "cp templates/%[1]s.service %[1]s-%[2]s-amd64/usr/lib/systemd/system/%[1]s.service",
    "cp templates/uphold.conf.tpl %[1]s-%[2]s-amd64/usr/lib/systemd/system/multi-user.target.d/10-%[1]s.conf",
    "echo -n '%[1]s.service' >> %[1]s-%[2]s-amd64/usr/lib/systemd/system/multi-user.target.d/10-%[1]s.conf",
  ]
  templates = merge(
    {
      for package in [
        "cloudflared",
        "consul-template",
        "consul",
        "coredns",
        "firecracker",
        "lego",
        "nomad",
        "node-exporter",
        "alloy",
        "step-ca",
        "tailscale",
        "vault",
        ] : package => concat(
        [
          for subdirectory in local.default_sysext_dir : "mkdir -p ${package}-${local.syspkgs[package].version}-amd64/${subdirectory}"
        ],
        [
          "cp templates/sysext-header.tpl ${package}-${local.syspkgs[package].version}-amd64/usr/lib/extension-release.d/extension-release.${package}-${local.syspkgs[package].version}-x86-64"
        ]
      )
    },
    {
      "cni-plugins" = concat(
        [
          for subdirectory in ["/usr/lib/cni", "usr/lib/extension-release.d"] : "mkdir -p cni-plugins-${local.syspkgs["cni-plugins"].version}-amd64/${subdirectory}"
        ],
        [
          "cp templates/sysext-header.tpl cni-plugins-${local.syspkgs["cni-plugins"].version}-amd64/usr/lib/extension-release.d/extension-release.cni-plugins-${local.syspkgs["cni-plugins"].version}-x86-64",
        ],
      )
    }
  )
}
