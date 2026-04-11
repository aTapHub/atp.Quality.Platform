resource "time_sleep" "wait_for_cluster_destroy" {
  depends_on = [digitalocean_kubernetes_cluster.atp_cluster]

  destroy_duration = "90s"
}

resource "digitalocean_vpc" "atp_vpc" {
  name   = "atp-quality-vpc"
  region = "fra1"

  depends_on = [time_sleep.wait_for_cluster_destroy]
}