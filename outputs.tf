output "ingress_host" {
  description = "The ingress host for the Argo CD instance"
  value       = local.host
  depends_on  = [null_resource.argocd-config]
  sensitive   = true
}

output "ingress_url" {
  description = "The ingress url for the Argo CD instance"
  value       = local.url_endpoint
  depends_on  = [null_resource.argocd-config]
  sensitive   = true
}

output "provision_tekton" {
  description = "Flag indicating that Tekton should be provisioned"
  value       = !local.openshift_gitops
  depends_on  = [null_resource.argocd-config]
}

output "namespace" {
  description = "The namespace where the ArgoCD instance has been provisioned"
  value       = local.app_namespace
  depends_on  = [null_resource.argocd-config]
}

output "username" {
  description = "The username of the default ArgoCD admin user"
  value       = "admin"
  depends_on  = [null_resource.argocd-config]
}

output "password" {
  description = "The password of the default ArgoCD admin user"
  value       = data.local_file.argocd_password.content
  depends_on  = [null_resource.argocd-config]
  sensitive   = true
}
