output "ingress_host" {
  description = "The ingress host for the Argo CD instance"
  value       = local.host
  depends_on  = [helm_release.argocd-config]
}

output "ingress_url" {
  description = "The ingress url for the Argo CD instance"
  value       = local.url_endpoint
  depends_on  = [helm_release.argocd-config]
}
