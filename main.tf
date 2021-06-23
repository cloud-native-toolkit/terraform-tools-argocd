
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
  argocd_values       = {
    global = {
      ingressSubdomain = var.ingress_subdomain
      tlsSecretName = local.tls_secret_name
      clusterType = var.cluster_type
    }
    openshift-gitops = {
      enabled = local.openshift_gitops
      instance = {
        dex = {
          openShiftOAuth = true
        }
      }
    }
    argocd-operator = {
      enabled = !local.openshift_gitops
      controllerRbac = true
    }
  }
  argocd_values_file = "${local.tmp_dir}/values-argocd.yaml"
  argocd_config_values = {
    name = "ArgoCD"
    url = local.url_endpoint
    otherConfig = {
      grpc_url = var.cluster_type == "kubernetes" ? local.grpc_url_endpoint : ""
    }
    username = "admin"
    password = data.local_file.argocd_password.content
    applicationMenu = var.cluster_type == "ocp4"
    ingressSubdomain = var.ingress_subdomain
  }
  argocd_config_values_file = "${local.tmp_dir}/values-argocd-config.yaml"
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

resource local_file argocd_values {
  filename = local.argocd_values_file
  content  = yamlencode(local.argocd_values)
}

resource null_resource argocd_helm {
  depends_on = [null_resource.delete_argocd_helm, local_file.argocd_values]

  triggers = {
    namespace = var.app_namespace
    name = "argocd"
    chart = "${path.module}/charts/argocd"
    values_file = local.argocd_values
    kubeconfig = var.cluster_config_file
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart} ${self.triggers.values_file}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart} ${self.triggers.values_file}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
    }
  }
}

resource null_resource get_argocd_password {
  depends_on = [null_resource.argocd_helm]

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

resource local_file argocd_config_values {
  filename = local.argocd_config_values_file
  content = yamlencode(local.argocd_config_values)
}

resource null_resource argocd-config {
  depends_on = [null_resource.delete_argocd_config_helm, local_file.argocd_config_values]

  triggers = {
    namespace = var.app_namespace
    name = "argocd-config"
    chart = "tool-config"
    repository = "https://charts.cloudnativetoolkit.dev"
    values_file = local.argocd_config_values_file
    kubeconfig = var.cluster_config_file
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart} ${self.triggers.values_file}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      REPO = self.triggers.repository
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart} ${self.triggers.values_file}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      REPO = self.triggers.repository
    }
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
