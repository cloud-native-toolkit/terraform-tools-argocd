module "dev_tools_argocd" {
  source = "./module"

  cluster_config_file = module.dev_cluster.config_file_path
  olm_namespace       = module.dev_capture_olm_state.namespace
  app_namespace       = module.dev_gitops_namespace.name
  name                = "argocd"
}

resource "null_resource" "output_values" {
  provisioner "local-exec" {
    command = "echo -n '${module.dev_capture_tools_state.namespace}' > .namespace"
  }
  provisioner "local-exec" {
    command = "echo -n '${module.dev_tools_argocd.namespace}' > .argo-namespace"
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
