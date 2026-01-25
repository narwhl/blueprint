locals {
  consul_service_name = var.consul_provider_config != null ? (var.consul_provider_config.service_name == "" ? var.controller_job_name : var.consul_provider_config.service_name) : "${var.controller_job_name}-ingress-controller"
  protocol            = var.use_https ? "https" : "http"
}

data "cloudflare_api_token_permission_groups" "all" {
  count = var.acme_email == "" ? 0 : 1
}

data "cloudflare_zone" "this" {
  count = var.acme_email == "" ? 0 : 1
  name  = var.dns_zone_name
}

resource "random_id" "tunnel_name" {
  count       = var.cloudflare_tunnel_name == "" ? 1 : 0
  byte_length = 3
}

resource "random_id" "tunnel_secret" {
  byte_length = 32
}

resource "cloudflare_tunnel" "ingress" {
  count      = var.cloudflare_account_id == "" ? 0 : 1
  account_id = var.cloudflare_account_id
  name       = var.cloudflare_tunnel_name == "" ? "ingress-${random_id.tunnel_name[0].hex}" : var.cloudflare_tunnel_name
  secret     = random_id.tunnel_secret.b64_std
  config_src = var.cloudflare_tunnel_config_source
}

resource "cloudflare_api_token" "dns_challenge_token" {
  count = var.acme_email == "" ? 0 : 1
  name  = "Ephemeral Token for ACME TLS Challenge"

  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all[0].zone["DNS Write"],
    ]
    resources = {
      "com.cloudflare.api.account.zone.${data.cloudflare_zone.this[0].id}" = "*"
    }
  }
}

data "consul_service" "ingress" {
  count      = var.cloudflare_account_id != "" && var.cloudflare_tunnel_config_source == "cloudflare" ? 1 : 0
  name       = local.consul_service_name
  datacenter = var.datacenter_name

  depends_on = [
    nomad_job.ingress-controller,
    nomad_job.ingress-gateway
  ]
}

resource "cloudflare_tunnel_config" "ingress" {
  count      = var.cloudflare_account_id != "" && var.cloudflare_tunnel_config_source == "cloudflare" ? 1 : 0
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.ingress[0].id

  config {
    ingress_rule {
      service = "${local.protocol}://${data.consul_service.ingress[0].service[0].address}:${data.consul_service.ingress[0].service[0].port}"
    }
  }

  depends_on = [data.consul_service.ingress]
}

resource "nomad_job" "ingress-controller" {
  jobspec = templatefile(
    "${path.module}/templates/traefik.nomad.hcl.tftpl",
    {
      job_name        = var.controller_job_name
      datacenter_name = var.datacenter_name
      namespace       = var.namespace
      version         = var.traefik_version
      protocol        = local.protocol
      acme_config = var.acme_email == "" ? [] : [{
        acme_email   = var.acme_email
        cf_api_token = cloudflare_api_token.dns_challenge_token[0].value
      }]
      nomad_config = var.nomad_provider_config == null ? [] : [{
        # https://github.com/hashicorp/consul-template/blob/main/README.md#multi-phase-execution
        address = var.nomad_provider_config.address == "" ? "{{ with service `nomad` }}{{ with index . 0 }}http://{{ .Address }}:4646{{ end }}{{ end }}" : var.nomad_provider_config.address
      }]
      consul_config = var.consul_provider_config == null ? [] : [{
        address       = var.consul_provider_config.address == "" ? "{{ with service `consul` }}{{ with index . 0 }}http://{{ .Address }}:8500{{ end }}{{ end }}" : var.consul_provider_config.address
        connect_aware = var.consul_provider_config.connect_aware
        service_name  = var.consul_provider_config.service_name == "" ? var.controller_job_name : var.consul_provider_config.service_name
        sidecars      = var.consul_provider_config.connect_aware ? [] : [{}]
      }]
      static_routes                 = var.static_routes
      enable_http_to_https_redirect = var.enable_http_to_https_redirect
    }
  )
}

resource "nomad_job" "ingress-gateway" {
  count = var.cloudflare_account_id == "" ? 0 : 1
  jobspec = templatefile(
    "${path.module}/templates/cloudflared.nomad.hcl.tftpl",
    {
      job_name        = var.gateway_job_name
      datacenter_name = var.datacenter_name
      namespace       = var.namespace
      version         = var.cloudflared_version
      http2_config    = var.use_https ? [{}] : []
      remote_ingress_config = var.cloudflare_tunnel_config_source == "cloudflare" ? [{
        tunnel_token = cloudflare_tunnel.ingress[0].tunnel_token
      }] : []
      local_ingress_config = var.cloudflare_tunnel_config_source == "local" ? [{
        tunnel = cloudflare_tunnel.ingress[0].id
        tunnel_credentials = jsonencode({
          AccountTag   = var.cloudflare_account_id
          TunnelName   = cloudflare_tunnel.ingress[0].name
          TunnelSecret = cloudflare_tunnel.ingress[0].secret
          TunnelID     = cloudflare_tunnel.ingress[0].id
        })
        ingress_config = yamlencode({
          tunnel           = cloudflare_tunnel.ingress[0].id
          credentials-file = "{{ env `NOMAD_SECRETS_DIR` }}/tunnel-credentials.json"
          ingress = [merge({
            service = "{{ with service `${local.consul_service_name}` }}{{ with index . 0 }}${local.protocol}://{{ .Address }}:{{ .Port }}{{ end }}{{ end }}"
            }, var.use_https ? {
            originRequest = {
              noTLSVerify = true
              http2Origin = true
            }
          } : {})]
        })
      }] : []
    }
  )
}
