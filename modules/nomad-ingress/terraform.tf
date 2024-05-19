terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.33.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "2.20.0"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "2.2.0"
    }
  }
}
