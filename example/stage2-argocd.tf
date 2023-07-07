module "dev_tools_argocd" {
  source = "../"

  cluster_config_file = module.cluster.config_file_path
  cluster_type        = module.cluster.platform.type_code
  ingress_subdomain   = module.cluster.platform.ingress
  tls_secret_name     = module.cluster.platform.tls_secret
  olm_namespace       = module.olm.olm_namespace
  operator_namespace  = module.olm.target_namespace
  name                = "argocd"
}

resource "null_resource" "output_values" {
  provisioner "local-exec" {
    command = "echo -n '${module.dev_tools_argocd.namespace}' > .namespace"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.dev_tools_argocd.operator_namespace}' > .operator_namespace"
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
