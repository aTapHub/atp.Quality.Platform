terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
  cloud {
    
    organization = "atp-quality-platform"

    workspaces {
      name = "atp-quality-platform"
    }
  }
}

provider "digitalocean" {
 
}

