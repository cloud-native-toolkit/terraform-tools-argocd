module "olm" {
  source = "github.com/ibm-garage-cloud/terraform-software-olm.git"

  cluster_config_file      = module.cluster.config_file_path
}
