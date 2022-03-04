variable "cluster_config_file" {
  type        = string
  description = "Cluster config file for Kubernetes cluster."
}

variable "cluster_type" {
  type        = string
  description = "The type of cluster (openshift or kubernetes)"
  default     = "ocp4"
}

variable "olm_namespace" {
  type        = string
  description = "Namespace where olm is installed"
}

variable "app_namespace" {
  type        = string
  description = "Namespace where the ArgoCD instance will be installed"
  default     = "openshift-gitops"
}

variable "name" {
  type        = string
  description = "The name for the instance"
  default     = "argocd-cluster"
}
