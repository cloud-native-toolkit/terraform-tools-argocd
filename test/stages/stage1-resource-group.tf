module "resource_group" {
  source = "github.com/cloud-native-toolkit/terraform-ibm-resource-group.git"

  resource_group_name = var.resource_group_name
  ibmcloud_api_key    = var.ibmcloud_api_key
  provision           = false
}
