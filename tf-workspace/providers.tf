terraform {
  required_version = "~> 1.6"

  backend "remote" {
    organization = "o11ystack"
    workspaces {
      name = "spotlight"
    }
  }

  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "~> 1.49.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.3"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.6"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}
