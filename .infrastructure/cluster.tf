resource "digitalocean_kubernetes_cluster" "atp_cluster" {
  name    = "atp-quality-cluster"
  region  = "fra1"
  version = var.do_kubernetes_version

  vpc_uuid = digitalocean_vpc.atp_vpc.id

  node_pool {
    name       = "autoscale-worker-pool"
    size       = "s-2vcpu-4gb"
    node_count = 3
  }
}