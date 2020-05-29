provider "helm" {
  version = ">= 1.1.1"

  kubernetes {
    config_path = var.cluster_config_file
  }
}

locals {
  tmp_dir       = "${path.cwd}/.tmp"
  host          = "${var.name}-server-${var.app_namespace}.${var.ingress_subdomain}"
  url_endpoint  = "https://${local.host}"
  password_file = "${local.tmp_dir}/argocd-password.val"
}

resource "null_resource" "argocd-subscription" {
  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-subscription.sh ${var.cluster_type} ${var.app_namespace} ${var.olm_namespace}"

    environment = {
      TMP_DIR    = local.tmp_dir
      KUBECONFIG = var.cluster_config_file
    }
  }
}

resource "null_resource" "argocd-instance" {
  depends_on = [null_resource.argocd-subscription]

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-instance.sh ${var.cluster_type} ${var.app_namespace} ${var.ingress_subdomain} ${var.name}"

    environment = {
      KUBECONFIG    = var.cluster_config_file
      PASSWORD_FILE = local.password_file
    }
  }
}

data "local_file" "argocd-password" {
  depends_on = [null_resource.argocd-instance]

  filename = local.password_file
}

resource "helm_release" "argocd-config" {
  depends_on = [null_resource.argocd-instance]

  name         = "argocd"
  repository   = "https://ibm-garage-cloud.github.io/toolkit-charts/"
  chart        = "tool-config"
  namespace    = var.app_namespace
  force_update = true

  set {
    name  = "url"
    value = local.url_endpoint
  }

  set {
    name  = "username"
    value = var.cluster_type == "kubernetes" ? "admin" : ""
  }

  set_sensitive {
    name  = "password"
    value = var.cluster_type == "kubernetes" ? data.local_file.argocd-password.content : ""
  }

  set {
    name  = "applicationMenu"
    value = var.cluster_type != "kubernetes"
  }
}
