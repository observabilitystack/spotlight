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
      version = "~> 1.45.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}
