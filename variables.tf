variable "cluster_config_file" {
  type        = string
  description = "Cluster config file for Kubernetes cluster."
}

variable "ingress_subdomain" {
  type        = string
  description = "The subdomain to be used to create the ingress for the ArgoCD instance. (Needed to create ingress for k8s deployments)"
  default     = ""
}

variable "tls_secret_name" {
  type        = string
  description = "The name of the secret containing the tls information"
  default     = ""
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

variable "operator_namespace" {
  type        = string
  description = "Namespace where operator will be installed"
}

variable "name" {
  type        = string
  description = "The name for the instance"
  default     = "argocd-cluster"
}

variable "app_namespace" {
  type        = string
  description = "The namespace where the ArgoCD instance will be deployed. If not provided then will be installed in the default location (openshift-gitops or gitops)"
  default     = ""
}

variable "dummy" {
  default   = "dummy"
  sensitive = true
}