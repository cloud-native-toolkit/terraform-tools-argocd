module "dev_capture_tools_state" {
  source = "github.com/ibm-garage-cloud/terraform-k8s-capture-state"

  cluster_type             = module.dev_cluster.type_code
  cluster_config_file_path = module.dev_cluster.config_file_path
  namespace                = module.dev_tools_namespace.name
  output_path              = "${path.cwd}/cluster-state/before"
}

module "dev_capture_olm_state" {
  source = "github.com/ibm-garage-cloud/terraform-k8s-capture-state"

  cluster_type             = module.dev_cluster.type_code
  cluster_config_file_path = module.dev_cluster.config_file_path
  namespace                = module.dev_software_olm.olm_namespace
  output_path              = "${path.cwd}/cluster-state/before"
}

module "dev_capture_operator_state" {
  source = "github.com/ibm-garage-cloud/terraform-k8s-capture-state"

  cluster_type             = module.dev_cluster.type_code
  cluster_config_file_path = module.dev_cluster.config_file_path
  namespace                = module.dev_software_olm.target_namespace
  output_path              = "${path.cwd}/cluster-state/before"
}
