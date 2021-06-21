
locals {
  tmp_dir           = "${path.cwd}/.tmp"
  name              = "argocd-cluster"
  version_file      = "${local.tmp_dir}/argocd-cluster.version"
  cluster_version   = data.local_file.cluster_version.content
  version_re        = substr(local.cluster_version, 0, 1) == "4" ? regex("^4.([0-9]+)", local.cluster_version)[0] : ""
  openshift_gitops  = local.version_re == "6" || local.version_re == "7" || local.version_re == "8" || local.version_re == "9"
  app_namespace     = local.openshift_gitops ? "openshift-gitops" : var.app_namespace
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

resource null_resource print_version {
  provisioner "local-exec" {
    command = "echo 'Cluster version: ${local.version_re}'"
  }
  provisioner "local-exec" {
    command = "echo 'OpenShift GitOps: ${local.openshift_gitops}'"
  }
}

resource null_resource delete_argocd_helm {
  provisioner "local-exec" {
    command = "kubectl delete sa job-argocd -n ${local.app_namespace} || exit 0"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }

  provisioner "local-exec" {
    command = "kubectl delete job job-argocd -n ${local.app_namespace} || exit 0"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }

  provisioner "local-exec" {
    command = "kubectl delete sa job-openshift-gitops-operator -n ${local.app_namespace} || exit 0"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }

  provisioner "local-exec" {
    command = "kubectl delete job job-openshift-gitops-operator -n openshift-operators || exit 0"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }

  provisioner "local-exec" {
    command = "kubectl delete secret sh.helm.release.v1.argocd.v1 -n ${var.app_namespace} || exit 0"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

resource helm_release argocd {
  depends_on = [null_resource.delete_argocd_helm]

  name         = "argocd"
  chart        = "${path.module}/charts/argocd"
  namespace    = var.app_namespace
  force_update = true
  replace      = true

  set {
    name = "global.ingressSubdomain"
    value = var.ingress_subdomain
  }

  set {
    name = "global.tlsSecretName"
    value = local.tls_secret_name
  }

  set {
    name = "global.clusterType"
    value = var.cluster_type
  }

  set {
    name = "openshift-gitops.enabled"
    value = local.openshift_gitops
  }

  set {
    name = "openshift-gitops.instance.dex.openShiftOAuth"
    value = true
  }

  set {
    name = "argocd-operator.enabled"
    value = !local.openshift_gitops
  }

  set {
    name = "argocd-operator.controllerRbac"
    value = true
  }
}

resource null_resource print_argocd_manifest {
  provisioner "local-exec" {
    command = "echo '${helm_release.argocd.manifest}'"
  }
}

resource null_resource get_argocd_password {
  depends_on = [helm_release.argocd]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/get-argocd-password.sh ${local.app_namespace} ${local.password_file}"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

data local_file argocd_password {
  depends_on = [null_resource.get_argocd_password]

  filename = local.password_file
}

resource null_resource clean_up_instance {
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    when = destroy

    command = "echo 'Clean up instance'"
  }
}

resource "null_resource" "delete_argocd_config_helm" {
  provisioner "local-exec" {
    command = "kubectl api-resources | grep -q consolelink && kubectl delete consolelink -l grouping=garage-cloud-native-toolkit -l app=argocd || exit 0"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }

  provisioner "local-exec" {
    command = "kubectl delete -n ${var.app_namespace} secret sh.helm.release.v1.argocd-config.v1 || exit 0"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

resource "helm_release" "argocd-config" {
  depends_on = [null_resource.clean_up_instance, null_resource.delete_argocd_config_helm]

  name         = "argocd-config"
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
    value = data.local_file.argocd_password.content
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
