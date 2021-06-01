
locals {
  tmp_dir           = "${path.cwd}/.tmp"
  name              = "argocd-cluster"
  version_file      = "${local.tmp_dir}/argocd-cluster.version"
  cluster_version   = data.local_file.cluster_version.content
  version_re        = var.cluster_type == "ocp4" ? regex("^4.([0-9]+)", local.cluster_version)[0] : ""
  app_namespace     = local.version_re == "6" || local.version_re == "7" || local.version_re == "8" || local.version_re == "9" ? "openshift-gitops" : var.app_namespace
  host              = "${local.name}-server-${local.app_namespace}.${var.ingress_subdomain}"
  grpc_host         = "${local.name}-server-grpc-${local.app_namespace}.${var.ingress_subdomain}"
  url_endpoint      = "https://${local.host}"
  grpc_url_endpoint = "https://${local.grpc_host}"
  password_file     = "${local.tmp_dir}/argocd-password.val"
  tls_secret_name   = regex("([^.]+).*", var.ingress_subdomain)[0]
}

resource null_resource cluster_version {
  provisioner "local-exec" {
    command = "${path.module}/scripts/get-cluster-version.sh ${local.version_file}"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

data local_file cluster_version {
  depends_on = [null_resource.cluster_version]

  filename = local.version_file
}

resource "null_resource" "argocd-subscription" {
  depends_on = [null_resource.cluster_version]

  triggers = {
    kubeconfig = var.cluster_config_file
    namespace  = local.app_namespace
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-subscription.sh ${var.cluster_type} ${self.triggers.namespace} ${var.olm_namespace} ${local.cluster_version}"

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
    namespace  = local.app_namespace
    name       = local.name
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-instance.sh '${var.cluster_type}' '${self.triggers.namespace}' '${var.ingress_subdomain}' '${self.triggers.name}' '${local.cluster_version}'"

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

  provisioner "local-exec" {
    command = "kubectl delete -n ${local.app_namespace} secret sh.helm.release.v1.argocd-rbac.v1 || exit 0"

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
  namespace    = local.app_namespace
  force_update = true
  replace      = true

  set {
    name  = "controllerRbac"
    value = true
  }
}

resource "null_resource" "delete-argocd-helm" {
  provisioner "local-exec" {
    command = "kubectl api-resources | grep -q consolelink && kubectl delete consolelink -l grouping=garage-cloud-native-toolkit -l app=argocd || exit 0"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }

  provisioner "local-exec" {
    command = "kubectl delete -n ${local.app_namespace} secret sh.helm.release.v1.argocd.v1 || exit 0"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

resource "helm_release" "argocd-config" {
  depends_on = [null_resource.argocd-instance, null_resource.delete-argocd-helm]

  name         = "argocd"
  repository   = "https://charts.cloudnativetoolkit.dev"
  chart        = "tool-config"
  namespace    = local.app_namespace
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

//resource "null_resource" "delete-solsa-helm" {
//  provisioner "local-exec" {
//    command = "kubectl delete -n ${local.app_namespace} secret sh.helm.release.v1.solsa.v1 || exit 0"
//
//    environment = {
//      KUBECONFIG = var.cluster_config_file
//    }
//  }
//}
//
//resource "helm_release" "solsa" {
//  depends_on = [null_resource.argocd-instance, null_resource.delete-solsa-helm]
//
//  name         = "solsa"
//  chart        = "${path.module}/charts/solsa-cm"
//  namespace    = local.app_namespace
//  force_update = true
//
//  set {
//    name  = "ingress.subdomain"
//    value = var.ingress_subdomain
//  }
//
//  set {
//    name  = "ingress.tlssecret"
//    value = local.tls_secret_name
//  }
//}
//
//resource "null_resource" "install-solsa-plugin" {
//  depends_on = [helm_release.solsa]
//
//  provisioner "local-exec" {
//    command = "${path.module}/scripts/patch-solsa.sh ${local.app_namespace} ${local.name}"
//
//    environment = {
//      KUBECONFIG = var.cluster_config_file
//    }
//  }
//}
//
//resource "null_resource" "install-key-protect-plugin" {
//  depends_on = [null_resource.argocd-instance, null_resource.install-solsa-plugin]
//
//  provisioner "local-exec" {
//    command = "${path.module}/scripts/install-key-protect-plugin.sh ${local.app_namespace} ${local.name}"
//
//    environment = {
//      KUBECONFIG = var.cluster_config_file
//      TMP_DIR    = local.tmp_dir
//    }
//  }
//}
