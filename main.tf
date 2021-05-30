
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

resource "null_resource" "delete-rbac" {
  provisioner "local-exec" {
    command = "kubectl delete clusterrole/argocd-application-controller || kubectl delete clusterrolebinding/argocd-application-controller || kubectl delete clusterrole,clusterrolebinding -l app=argocd || exit 0"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

resource "helm_release" "argocd-rbac" {
  depends_on = [null_resource.argocd-instance, null_resource.delete-rbac]

  name         = "argocd-rbac"
  repository   = "https://charts.cloudnativetoolkit.dev"
  chart        = "argocd-config"
  namespace    = var.app_namespace
  force_update = true
  replace      = true

  set {
    name  = "controllerRbac"
    value = true
  }
}

resource "null_resource" "delete-consolelink" {
  count = var.cluster_type != "kubernetes" ? 1 : 0

  provisioner "local-exec" {
    command = "kubectl delete consolelink -l grouping=garage-cloud-native-toolkit -l app=argocd || exit 0"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

resource "helm_release" "argocd-config" {
  depends_on = [null_resource.argocd-instance, null_resource.delete-consolelink]

  name         = "argocd"
  repository   = "https://charts.cloudnativetoolkit.dev"
  chart        = "tool-config"
  namespace    = var.app_namespace
  force_update = true

  set {
    name  = "name"
    value = "ArgoCD"
  }

  set {
    name  = "url"
    value = local.url_endpoint
  }

  set {
    name  = "otherConfig.grpc_url"
    value = var.cluster_type == "kubernetes" ? local.grpc_url_endpoint : ""
  }

  set {
    name  = "username"
    value = "admin"
  }

  set_sensitive {
    name  = "password"
    value = data.local_file.argocd-password.content
  }

  set {
    name  = "applicationMenu"
    value = var.cluster_type == "ocp4"
  }

  set {
    name  = "ingressSubdomain"
    value = var.ingress_subdomain
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

resource "null_resource" "install-solsa-plugin" {
  depends_on = [helm_release.solsa]

  provisioner "local-exec" {
    command = "${path.module}/scripts/patch-solsa.sh ${var.app_namespace} ${var.name}"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

resource "null_resource" "install-key-protect-plugin" {
  depends_on = [null_resource.argocd-instance, null_resource.install-solsa-plugin]

  provisioner "local-exec" {
    command = "${path.module}/scripts/install-key-protect-plugin.sh ${var.app_namespace} ${var.name}"

    environment = {
      KUBECONFIG = var.cluster_config_file
      TMP_DIR    = local.tmp_dir
    }
  }
}
