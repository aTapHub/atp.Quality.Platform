resource "digitalocean_vpc" "atp_vpc" {
  name   = "atp-quality-vpc"
  region = "fra1"

  provisioner "local-exec" {
    when    = destroy
    command = "sleep 90"
  }
}