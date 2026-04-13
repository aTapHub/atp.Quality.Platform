# 1. Kubernetes Provider Configuration
# This uses the credentials from the cluster resource to talk to the K8s API
provider "kubernetes" {
  host                   = digitalocean_kubernetes_cluster.atp_cluster.endpoint
  token                  = digitalocean_kubernetes_cluster.atp_cluster.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.atp_cluster.kube_config[0].cluster_ca_certificate)
}

# 2. Helm Provider Configuration
provider "helm" {
  kubernetes = {
    host                   = digitalocean_kubernetes_cluster.atp_cluster.endpoint
    token                  = digitalocean_kubernetes_cluster.atp_cluster.kube_config[0].token
    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.atp_cluster.kube_config[0].cluster_ca_certificate)
  }
}

# 3. Deploy the Online Boutique App
# Points to Google's official OCI (container-based) Helm registry
resource "helm_release" "online_boutique" {
  name       = "onlineboutique"
  repository = "oci://us-docker.pkg.dev/online-boutique-ci/charts"
  chart      = "onlineboutique"
  namespace  = "default"
  
  # Optimization Settings
  timeout = 1200            # 20m - required for cold image pulls across 11 microservices
  wait    = false           # Don't block on pod readiness — health_check job handles this
  atomic  = false           # gRPC probe timeout on emailservice/recommendationservice causes false failures

  # Ensures a clean state if the first install fails
  cleanup_on_fail = true

}

# 4. Wait for DigitalOcean to assign the LoadBalancer IP
# Helm finishes when pods are Ready, but DO takes ~60s longer to provision the external IP
resource "time_sleep" "wait_for_lb" {
  depends_on      = [helm_release.online_boutique]
  create_duration = "90s"
}

# 5. Interrogate the cluster for the LoadBalancer IP
data "kubernetes_service" "frontend_lb" {
  metadata {
    name      = "frontend-external"
    namespace = "default"
  }

  depends_on = [time_sleep.wait_for_lb]
}

# 6. Output the final URL
# This will show up in your terminal and your GitHub Actions logs
output "boutique_public_url" {
  value       = try("http://${data.kubernetes_service.frontend_lb.status[0].load_balancer[0].ingress[0].ip}", null)
  description = "Access the Online Boutique here"
}