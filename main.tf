provider "helm" {
  version = ">= 1.1.1"

  kubernetes {
    config_path = var.cluster_config_file
  }
}

locals {
  tmp_dir           = "${path.cwd}/.tmp"
  host              = "${var.name}-server-${var.app_namespace}.${var.ingress_subdomain}"
  grpc_host         = "${var.name}-server-grpc-${var.app_namespace}.${var.ingress_subdomain}"
  url_endpoint      = "https://${local.host}"
  grpc_url_endpoint = "https://${local.grpc_host}"
  password_file     = "${local.tmp_dir}/argocd-password.val"
  tls_secret_name   = regex("([^.]+).*", var.ingress_subdomain)[0]
}

resource "null_resource" "argocd-subscription" {
  triggers = {
    kubeconfig = var.cluster_config_file
    namespace  = var.app_namespace
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-subscription.sh ${var.cluster_type} ${self.triggers.namespace} ${var.olm_namespace}"

    environment = {
      TMP_DIR    = local.tmp_dir
      KUBECONFIG = self.triggers.kubeconfig
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-subscription.sh ${self.triggers.namespace}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
    }
  }
}

resource "null_resource" "argocd-instance" {
  depends_on = [null_resource.argocd-subscription]

  triggers = {
    kubeconfig = var.cluster_config_file
    namespace  = var.app_namespace
    name       = var.name
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-instance.sh ${var.cluster_type} ${self.triggers.namespace} ${var.ingress_subdomain} ${self.triggers.name}"

    environment = {
      KUBECONFIG    = self.triggers.kubeconfig
      PASSWORD_FILE = local.password_file
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-instance.sh ${self.triggers.namespace} ${self.triggers.name}"

    environment = {
      KUBECONFIG    = self.triggers.kubeconfig
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
    name  = "otherConfig.grpc_url"
    value = local.grpc_url_endpoint
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


resource "helm_release" "solsa" {
  depends_on = [null_resource.argocd-instance]

  name         = "solsa"
  chart        = "${path.module}/charts/solsa-cm"
  namespace    = var.app_namespace
  force_update = true

  set {
    name  = "ingress.subdomain"
    value = var.ingress_subdomain
  }

  set {
    name  = "ingress.tlssecret"
    value = local.tls_secret_name
  }
}

resource "null_resource" "patch-solsa" {
  depends_on = [helm_release.solsa]

  provisioner "local-exec" {
    command = "${path.module}/scripts/patch-solsa.sh ${var.app_namespace}"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}