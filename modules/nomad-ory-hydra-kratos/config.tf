locals {
  # Transform email templates: auto-encode content, passthrough uri
  email_template_uris = var.kratos_email_templates == null ? {} : {
    for template_name, template in var.kratos_email_templates : template_name => {
      subject = template.subject != null ? "base64://${base64encode(template.subject)}" : null
      body = {
        html = (
          template.body_html.content != null
          ? "base64://${base64encode(template.body_html.content)}"
          : template.body_html.uri
        )
        plaintext = (
          template.body_text.content != null
          ? "base64://${base64encode(template.body_text.content)}"
          : template.body_text.uri
        )
      }
    } if template != null
  }

  # Build the templates config structure for Kratos
  kratos_courier_templates = length(local.email_template_uris) == 0 ? null : {
    recovery = merge(
      lookup(local.email_template_uris, "recovery_valid", null) != null ? {
        valid = { email = local.email_template_uris["recovery_valid"] }
      } : {},
      lookup(local.email_template_uris, "recovery_invalid", null) != null ? {
        invalid = { email = local.email_template_uris["recovery_invalid"] }
      } : {}
    )
    recovery_code = merge(
      lookup(local.email_template_uris, "recovery_code_valid", null) != null ? {
        valid = { email = local.email_template_uris["recovery_code_valid"] }
      } : {},
      lookup(local.email_template_uris, "recovery_code_invalid", null) != null ? {
        invalid = { email = local.email_template_uris["recovery_code_invalid"] }
      } : {}
    )
    verification = merge(
      lookup(local.email_template_uris, "verification_valid", null) != null ? {
        valid = { email = local.email_template_uris["verification_valid"] }
      } : {},
      lookup(local.email_template_uris, "verification_invalid", null) != null ? {
        invalid = { email = local.email_template_uris["verification_invalid"] }
      } : {}
    )
    verification_code = merge(
      lookup(local.email_template_uris, "verification_code_valid", null) != null ? {
        valid = { email = local.email_template_uris["verification_code_valid"] }
      } : {},
      lookup(local.email_template_uris, "verification_code_invalid", null) != null ? {
        invalid = { email = local.email_template_uris["verification_code_invalid"] }
      } : {}
    )
    login_code = lookup(local.email_template_uris, "login_code_valid", null) != null ? {
      valid = { email = local.email_template_uris["login_code_valid"] }
    } : {}
    registration_code = lookup(local.email_template_uris, "registration_code_valid", null) != null ? {
      valid = { email = local.email_template_uris["registration_code_valid"] }
    } : {}
  }

  # Filter out empty template categories
  kratos_courier_templates_filtered = local.kratos_courier_templates == null ? null : {
    for k, v in local.kratos_courier_templates : k => v if length(v) > 0
  }

  kratos_config = yamlencode({
    identity = {
      default_schema_id = "default"
      schemas = [
        {
          id  = "default"
          url = "base64://${base64encode(var.kratos_identity_schema)}"
        }
      ]
    }
    serve = {
      public = {
        base_url = "https://${local.kratos_public_fqdn}" # TODO: make https and subpath configurable
        cors = {
          # https://www.ory.sh/docs/kratos/guides/setting-up-cors
          enabled = true
          allowed_origins = [
            "https://${var.root_domain}",
            "https://*.${var.root_domain}"
          ]
          allowed_methods = [
            "GET",
            "POST",
            "PUT",
            "PATCH",
            "DELETE"
          ]
          allowed_headers = [
            "Authorization",
            "Content-Type",
            "Cookie"
          ]
          exposed_headers = [
            "Set-Cookie",
            "Content-Type",
          ]
        }
      }
      admin = {
        base_url = "https://${local.kratos_admin_fqdn}" # TODO: make https and subpath configurable
      }
    }
    selfservice = {
      default_browser_return_url = local.kratos_ui_url
      allowed_return_urls = [
        local.kratos_ui_url
      ]
      methods = {
        password = {
          enabled = true
          config = {
            min_password_length                 = var.kratos_password_policy.min_password_length
            haveibeenpwned_enabled              = var.kratos_password_policy.haveibeenpwned_enabled
            identifier_similarity_check_enabled = var.kratos_password_policy.identifier_similarity_check_enabled
          }
        }
        totp = {
          config = {
            issuer = var.application_name
          }
          enabled = true
        }
        lookup_secret = {
          enabled = true
        }
        link = {
          enabled = true
        }
        code = {
          enabled = true
        }
        webauthn = {
          enabled = var.kratos_webauthn_enabled
          config = {
            passwordless = true
            rp = {
              display_name = var.application_name
              id           = local.kratos_ui_fqdn
              origin       = local.kratos_ui_url
            }
          }
        }
        passkey = {
          enabled = var.kratos_passkey_enabled
          config = {
            rp = {
              display_name = var.application_name
              id           = local.kratos_ui_fqdn
              origin       = local.kratos_ui_url
            }
          }
        }
        oidc = {
          enabled = length(var.kratos_oidc_providers) > 0
          config = {
            base_redirect_uri = "https://${local.kratos_public_fqdn}"
            providers = [
              for provider in var.kratos_oidc_providers : {
                id            = provider.id
                provider      = provider.provider
                client_id     = provider.client_id
                client_secret = format(local.nomad_var_template, "oidc_${provider.id}_client_secret")
                scope         = provider.scope
                mapper_url    = "base64://${base64encode(provider.data_mapper)}"
              }
            ]
          }
        }
      }

      flows = {
        error = {
          ui_url = "${local.kratos_ui_url}/error"
        }

        settings = {
          ui_url = "${local.kratos_ui_url}/settings"

          after = {
            hooks = [for webhook in var.settings_webhooks :
              {
                hook = "web_hook"
                config = {
                  url     = webhook.url
                  method  = webhook.method
                  headers = webhook.headers
                  body    = "base64://${base64encode(webhook.body)}"
                }
              }
            ]
          }
        }

        recovery = {
          enabled = var.kratos_recovery_enabled
          ui_url  = "${local.kratos_ui_url}/recovery"
        }

        verification = {
          enabled = var.kratos_verification_enabled
          ui_url  = "${local.kratos_ui_url}/verification"

          after = {
            default_browser_return_url = local.kratos_ui_url
          }
        }

        logout = {
          after = {
            default_browser_return_url = "${local.kratos_ui_url}/login"
          }
        }

        login = {
          ui_url   = "${local.kratos_ui_url}/login"
          lifespan = "10m"
        }

        registration = {
          enabled  = var.kratos_registration_enabled
          ui_url   = "${local.kratos_ui_url}/registration"
          lifespan = "10m"
          after = {
            password = {
              hooks = []
            }
            hooks = [for webhook in var.registration_webhooks :
              {
                hook = "web_hook"
                config = {
                  url     = webhook.url
                  method  = webhook.method
                  headers = webhook.headers
                  body    = "base64://${base64encode(webhook.body)}"
                }
              }
            ]
          }
        }
      }
    }

    session = {
      cookie = {
        domain    = var.root_domain
        same_site = "Lax"
      }
    }

    cookies = {
      domain    = var.root_domain
      same_site = "Lax"
    }

    hashers = {
      algorithm = "bcrypt"
      bcrypt = {
        cost = 8
      }
    }

    ciphers = {
      alogrithm = "xchacha20-poly1305"
    }

    secrets = {
      cipher = [
        format(local.nomad_var_template, "kratos_secret_cipher")
      ]
      cookie = [
        format(local.nomad_var_template, "kratos_cookie_secret")
      ]
    }

    courier = merge(
      {
        smtp = {
          connection_uri = format(local.nomad_var_template, "smtp_connection_uri")
          from_address   = var.email_from_address
          from_name      = var.email_from_name
        }
      },
      local.kratos_courier_templates_filtered != null && length(local.kratos_courier_templates_filtered) > 0 ? {
        templates = local.kratos_courier_templates_filtered
      } : {}
    )

    oauth2_provider = {
      url = "http://{{ range nomadService `hydra-admin` }}{{ .Address }}:{{ .Port }}{{ end }}"
    }
  })
  hydra_config = yamlencode({
    serve = {
      cookies = {
        same_site_mode = "Lax"
      }
    }

    urls = {
      self = {
        issuer = "https://${local.hydra_fqdn}"
      }
      consent = "${local.kratos_ui_url}/consent"
      login   = "${local.kratos_ui_url}/login"
      logout  = "${local.kratos_ui_url}/logout"
      identity_provider = {
        publicUrl = "https://${local.kratos_public_fqdn}" # TODO: make https configurable

        // headers = {
        //   "Authorization" = "Bearer ..."
        // }

        url = "http://{{ range nomadService `kratos-admin` }}{{ .Address }}:{{ .Port }}{{ end }}" # TODO: make https configurable
      }
    }

    secrets = {
      cookie = [
        format(local.nomad_var_template, "hydra_cookie_secret")
      ]
      system = [
        format(local.nomad_var_template, "hydra_system_secret")
      ]
    }

    oidc = {
      subject_identifiers = {
        supported_types = [
          "public",
          "pairwise"
        ]
        pairwise = {
          salt = format(local.nomad_var_template, "hydra_oidc_pairwise_salt")
        }
      }
    }

    ttl = {
      access_token          = "1h"
      refresh_token         = "1h"
      id_token              = "1h"
      auth_code             = "1h"
      login_consent_request = "1h"
    }

    oauth2 = {
      session = {
        encrypt_at_rest = false
      }
      exclude_not_before_claim = true
    }

  })
}
