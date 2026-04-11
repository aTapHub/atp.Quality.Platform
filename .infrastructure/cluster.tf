resource "digitalocean_kubernetes_cluster" "atp_cluster" {
  name    = "atp-quality-cluster"
  region  = "fra1"
  version = "1.31.1-do.0" 

  vpc_uuid = digitalocean_vpc.atp_vpc.id

  node_pool {
    name       = "autoscale-worker-pool"
    size       = "s-2vcpu-4gb" 
    node_count = 3             
  }
}