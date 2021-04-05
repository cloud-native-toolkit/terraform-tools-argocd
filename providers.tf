provider "helm" {
  kubernetes {
    config_path = var.cluster_config_file
  }
}
