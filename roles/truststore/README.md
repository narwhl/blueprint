# Truststore Role

Manages CA certificates in the system truststore.

## Requirements

- Debian/Ubuntu system
- Ansible 2.12+

## Role Variables

```yaml
# Single certificate content (legacy support)
cert_pem: |
  -----BEGIN CERTIFICATE-----
  ... certificate content ...
  -----END CERTIFICATE-----

# Multiple certificates
ca_certificates:
  - name: "example-ca"
    content: |
      -----BEGIN CERTIFICATE-----
      ... certificate content ...
      -----END CERTIFICATE-----
  - name: "another-ca"
    content: |
      -----BEGIN CERTIFICATE-----
      ... certificate content ...
      -----END CERTIFICATE-----

# Certificates to remove
remove_ca_certificates:
  - "old-ca-name"
  - "expired-ca-name"
```

## Dependencies

None

## Example Playbook

```yaml
- hosts: all
  roles:
    - role: truststore
      vars:
        ca_certificates:
          - name: "company-root-ca"
            content: "{{ company_root_ca_cert }}"
          - name: "company-intermediate-ca"
            content: "{{ company_intermediate_ca_cert }}"
```