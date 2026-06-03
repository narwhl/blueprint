# Docker Role

Installs Docker CE with proper service management, user group handling, and Docker Compose.

## Requirements

- Debian/Ubuntu system
- Ansible 2.12+

## Role Variables

```yaml
# Docker Compose installation
install_docker_compose: true
docker_compose_version: "2.24.1"

# Users to add to docker group
docker_users:
  - username1
  - username2

# Docker daemon configuration (optional)
docker_daemon_config:
  log-driver: "json-file"
  log-opts:
    max-size: "10m"
    max-file: "3"
  storage-driver: "overlay2"

# Docker systemd overrides (optional)
docker_systemd_overrides:
  Service:
    ExecStart: ""
    ExecStart: "/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock"
```

## Dependencies

None

## Example Playbook

```yaml
- hosts: docker-hosts
  roles:
    - role: docker
      vars:
        docker_users:
          - deployer
          - jenkins
```