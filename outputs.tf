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
  value       = true
  depends_on  = [null_resource.argocd-config]
}

output "operator_namespace" {
  description = "The namespace where the operator has been provisioend"
  value       = var.operator_namespace
  depends_on  = [null_resource.argocd-config]
}

output "namespace" {
  description = "The namespace where the ArgoCD instance has been provisioned"
  value       = var.app_namespace
  depends_on  = [null_resource.argocd-config]
}

output "service_account" {
  description = "The name of the service account for the ArgoCD instance has been provisioned"
  value       = local.service_account_name
  depends_on  = [null_resource.argocd-config]
}

output "username" {
  description = "The username of the default ArgoCD admin user"
  value       = "admin"
  depends_on  = [null_resource.argocd-config]
}

output "password" {
  description = "The password of the default ArgoCD admin user"
  value       = data.external.argocd_config.result.password
  depends_on  = [null_resource.argocd-config]
  sensitive   = true
}
