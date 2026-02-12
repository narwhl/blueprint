# Tailscale Role

Installs and configures Tailscale VPN with authentication setup and service management.

## Requirements

- Debian/Ubuntu or RHEL/CentOS system
- Ansible 2.12+

## Role Variables

```yaml
# Tailscale authentication
tailscale_auth_key: "your-auth-key"
tailscale_login_server: "https://your-headscale-server.com"

# Tailscale configuration
tailscale_hostname: "{{ inventory_hostname }}"
tailscale_exit_node: false
tailscale_ssh: false

# Subnet routes to advertise
tailscale_subnet_routes:
  - "192.168.1.0/24"
  - "10.0.0.0/8"

# Additional flags for 'tailscale up' command
tailscale_up_flags: "--accept-routes --accept-dns"
```

## Dependencies

None

## Example Playbook

```yaml
- hosts: tailscale-nodes
  roles:
    - role: tailscale
      vars:
        tailscale_auth_key: "{{ vault_tailscale_auth_key }}"
        tailscale_exit_node: true
        tailscale_ssh: true
```