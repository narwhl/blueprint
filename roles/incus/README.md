# Incus Role

Installs Incus container and VM manager with proper service management and initial configuration.

## Requirements

- Debian/Ubuntu system
- Ansible 2.12+

## Role Variables

```yaml
# Users to add to incus-admin group
incus_admin_users:
  - username1
  - username2

# Auto-initialize Incus
incus_auto_init: true

# Storage pool configuration (optional)
incus_storage_pool:
  name: "default"
  driver: "dir"
  config: "source=/var/lib/incus/storage-pools/default"

# Network configuration (optional)
incus_network:
  name: "incusbr0"
  config: "ipv4.address=10.0.0.1/24 ipv4.nat=true ipv6.address=none"

# Server configuration (optional)
incus_server_config:
  core.https_address: "[::]:"
  core.trust_password: "your-password"
```

## Dependencies

None

## Example Playbook

```yaml
- hosts: incus-hosts
  roles:
    - role: incus
      vars:
        incus_admin_users:
          - admin
          - developer
```