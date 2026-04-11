resource "digitalocean_vpc" "atp_vpc" {
  name   = "atp-quality-vpc"
  region = "fra1"
}