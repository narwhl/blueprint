#!/bin/bash
# Consul environment configuration

# Set Consul HTTP address
export CONSUL_HTTP_ADDR="${CONSUL_HTTP_ADDR:-http://127.0.0.1:8500}"

# Set Consul datacenter
export CONSUL_DATACENTER="${CONSUL_DATACENTER:-dc1}"

# Add consul command completion if available
if command -v consul >/dev/null 2>&1; then
    complete -C /usr/bin/consul consul
fi