module "dev_cluster" {
  source = "github.com/ibm-garage-cloud/terraform-ibm-container-platform.git"

  resource_group_name     = var.resource_group_name
  cluster_name            = var.cluster_name
  cluster_region          = var.region
  cluster_type            = var.cluster_type == "iks" ? "kubernetes" : var.cluster_type
  cluster_exists          = true
  ibmcloud_api_key        = var.ibmcloud_api_key
  name_prefix             = var.name_prefix
  is_vpc                  = false
  private_vlan_id         = ""
  public_vlan_id          = ""
  vlan_datacenter         = ""
  cluster_machine_type    = ""
  cluster_worker_count    = 3
  cluster_hardware        = ""
}
