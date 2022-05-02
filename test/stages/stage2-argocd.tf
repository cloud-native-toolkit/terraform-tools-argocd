module "dev_tools_argocd" {
  source = "./module"

  cluster_config_file = module.dev_cluster.config_file_path
  olm_namespace       = module.dev_software_olm.olm_namespace
  operator_namespace  = module.dev_software_olm.target_namespace
  app_namespace       = module.dev_tools_namespace.name
  name                = "argocd"
}

resource "null_resource" "output_values" {
  provisioner "local-exec" {
    command = "echo -n '${module.dev_tools_argocd.namespace}' > .namespace"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.dev_tools_argocd.ingress_host}' > .argo-host"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.dev_tools_argocd.ingress_url}' > .argo-url"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.dev_tools_argocd.username}' > .argo-username"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.dev_tools_argocd.password}' > .argo-password"
  }
}
