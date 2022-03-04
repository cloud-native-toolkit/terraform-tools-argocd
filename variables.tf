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

variable "operator_namespace" {
  type        = string
  description = "Namespace where operator will be installed"
}

variable "app_namespace" {
  type        = string
  description = "Namespace where operator instance will be installed"
}

variable "name" {
  type        = string
  description = "The name for the instance"
  default     = "argocd-cluster"
}
