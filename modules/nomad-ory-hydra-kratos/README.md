# Terraform module for self hosting Ory Hydra and Kratos on Nomad

### Usage

```hcl
module "ory" {
  source                 = "registry.narwhl.workers.dev/stack/idp/nomad"
  datacenter_name        = "dc1" # name of the datacenter in Nomad
  database_user          = "ory" # optional field, defaults to "ory", need to configure externally since db is not hosted from within this module
  database_password      = "my_secret_password" # required field, a single user will manages both hydra and kratos simultaneously
  database_addr          = "{ip_or_hostname}:{port}" # required field
  hydra_db_name          = "hydra" # optional field, defaults to "hydra"
  kratos_db_name         = "kratos" # optional field, defaults to "kratos"
  hydra_version          = "" # required field, should obtain this from oci image tag from registry
  kratos_version         = "" # required field, should obtain this from oci image tag from registry
  application_name       = "Acme Signle Sign-on" # required field
  root_domain            = "domain.tld" # required field, for composing subdomains that both hydra and kratos uses for its services
  hydra_subdomain        = "auth" # required field, for oauth server
  kratos_ui_subdomain    = "login" # required field, for idp login page, instance runs externally
  kratos_admin_subdomain = "accounts" # required field, for idp admin api
  smtp_connection_uri    = "smtp://{user:password}@{host:port}" # required field, http config for mail gateway tbd

  # optional: customize password policy (defaults shown below)
  kratos_password_policy = {
    min_password_length                 = 8
    haveibeenpwned_enabled              = true
    identifier_similarity_check_enabled = true
  }

  # optional: enable social login with OIDC providers
  kratos_oidc_providers = [
    {
      id            = "google"
      provider      = "google"
      client_id     = "your-google-client-id"
      client_secret = "your-google-client-secret"
      scope         = ["openid", "profile", "email"]
      data_mapper   = <<-EOT
        local claims = std.extVar('claims');
        {
          identity: {
            traits: {
              email: claims.email,
            },
          },
        }
      EOT
    }
  ]

  # optional: customize email templates
  kratos_email_templates = {
    recovery_valid = {
      subject = "Reset your password"
      body_html = {
        content = <<-HTML
          <html>
            <body>
              <h1>Password Reset</h1>
              <p>Click <a href="{{ .RecoveryURL }}">here</a> to reset your password.</p>
            </body>
          </html>
        HTML
      }
      body_text = {
        content = "Reset your password by visiting: {{ .RecoveryURL }}"
      }
    }
    # Or use remote templates:
    # verification_valid = {
    #   subject   = "Verify your email"
    #   body_html = { uri = "https://cdn.example.com/templates/verify.html.gotmpl" }
    #   body_text = { uri = "https://cdn.example.com/templates/verify.txt.gotmpl" }
    # }
  }
}
```

## Argument Reference

- `datacenter_name`: `(string: <required>)` - The name of the Nomad datacenter to use.

- `namespace`: `(string: <optional>)` - The namespace to run the job in. Defaults to `default`.

- `job_name`: `(string: <optional>)` - The name of the job. Defaults to `ory`.

- `database_addr`: `(string: <required>)` - The address of the Postgres database.

- `database_password`: `(string: <required>)` - The password of the Postgres database.

- `database_sslmode`: `(string: <optional>)` - The ssl mode of the Postgres database. Defaults to `disable`.

- `database_user`: `(string: <optional>)` - The username of the Postgres database. Defaults to `ory`.

- `hydra_db_name`: `(string: <optional>)` - The name of the hydra database. Defaults to `hydra`.

- `kratos_db_name`: `(string: <optional>)` - The name of the kratos database. Defaults to `kratos`.

- `hydra_version`: `(string: <required>)` - The version of Ory Hydra to run.

- `kratos_version`: `(string: <required>)` - The version of Ory Kratos to run.

- `application_name`: `(string: <required>)` - The name of the application.

- `root_domain`: `(string: <required>)` - The root domain for the subdomains.

- `hydra_subdomain`: `(string: <required>)` - The subdomain for the hydra service.

- `kratos_ui_subdomain`: `(string: <required>)` - The subdomain for the kratos ui service.

- `kratos_admin_subdomain`: `(string: <required>)` - The subdomain for the kratos admin service.

- `smtp_connection_uri`: `(string: <required>)` - The smtp connection uri for sending emails.

- `kratos_identity_schema`: `(string: <required>)` - The identity schema for kratos.

- `kratos_recovery_enabled`: `(bool: <optional>)` - Whether to enable account recovery. Defaults to `true`.

- `kratos_verification_enabled`: `(bool: <optional>)` - Whether to enable account verification. Defaults to `true`.

- `kratos_webauthn_enabled`: `(bool: <optional>)` - Whether to enable webauthn. Defaults to `false`.

- `kratos_passkey_enabled`: `(bool: <optional>)` - Whether to enable passkey. Defaults to `false`.

- `kratos_password_policy`: `(object: <optional>)` - Password policy configuration for Kratos. Defaults to secure settings recommended by Kratos.
  - `min_password_length`: `(number)` - Minimum password length. Defaults to `8`. Must be at least `6`.
  - `haveibeenpwned_enabled`: `(bool)` - Whether to check passwords against HaveIBeenPwned API. Defaults to `true`.
  - `identifier_similarity_check_enabled`: `(bool)` - Whether to check password similarity to user identifier. Defaults to `true`.

- `kratos_oidc_providers`: `(list(object): <optional>)` - List of OIDC/OAuth2 providers for social login. Defaults to `[]`. OIDC is automatically enabled when providers are configured. Each provider requires:
  - `id`: `(string)` - Unique identifier for the provider (e.g., "google", "github").
  - `provider`: `(string)` - Provider type (e.g., "google", "github", "microsoft", "generic"). See [Ory Kratos OIDC documentation](https://www.ory.com/docs/self-hosted/kratos/configuration/oidc) for supported providers.
  - `client_id`: `(string)` - OAuth2 client ID from the provider.
  - `client_secret`: `(string)` - OAuth2 client secret from the provider (stored securely in Nomad variables).
  - `scope`: `(list(string))` - OAuth2 scopes to request from the provider. Common scopes include "openid", "profile", "email".
  - `data_mapper`: `(string)` - Jsonnet code that maps provider claims to Kratos identity traits. The code will be automatically base64-encoded.

- `email_from_name`: `(string: <required>)` - The name of the email sender.

- `registration_webhooks`: `([]object: <optional>)` - The registration webhooks.

- `settings_webhooks`: `([]object: <optional>)` - The settings webhooks.

- `kratos_email_templates`: `(object: <optional>)` - Custom email templates for Kratos courier. Defaults to `null` (uses built-in templates). Each template type accepts:
  - `subject`: `(string)` - Email subject line (auto base64-encoded).
  - `body_html`: `(object)` - HTML body with either `content` (inline, auto-encoded) or `uri` (remote URL).
  - `body_text`: `(object)` - Plain text body with either `content` (inline, auto-encoded) or `uri` (remote URL).

  Available template types:
  - `recovery_valid` - Password recovery for existing users
  - `recovery_invalid` - Recovery request for non-existent users
  - `recovery_code_valid` - Code-based recovery for existing users
  - `recovery_code_invalid` - Code-based recovery for non-existent users
  - `verification_valid` - Email verification for existing users
  - `verification_invalid` - Verification for non-existent users
  - `verification_code_valid` - Code-based verification for existing users
  - `verification_code_invalid` - Code-based verification for non-existent users
  - `login_code_valid` - Passwordless login code
  - `registration_code_valid` - Registration confirmation code

- `traefik_entrypoints`: `(object: <optional>)` - The entrypoints to expose the service.

## Outputs

- `kratos_cookie_secret`: `string` - The cookie secret for Ory Kratos.
