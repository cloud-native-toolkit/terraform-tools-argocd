
locals {
  tmp_dir           = "${path.cwd}/.tmp"
  bin_dir           = module.setup_clis.bin_dir
  version_file      = "${local.tmp_dir}/argocd-cluster.version"
  host_file         = "${local.bin_dir}/argocd-cluster.host"
  cluster_version   = data.local_file.cluster_version.content
  version_re        = substr(local.cluster_version, 0, 1) == "4" ? regex("^4.([0-9]+)", local.cluster_version)[0] : ""
  name              = local.version_re == "6" ? "argocd-cluster" : "openshift-gitops"
  openshift_gitops  = local.version_re == "6" || local.version_re == "7" || local.version_re == "8" || local.version_re == "9"
  app_namespace     = local.openshift_gitops ? "openshift-gitops" : var.app_namespace
  host              = data.local_file.argocd_host.content
  grpc_host         = data.local_file.argocd_host.content
  url_endpoint      = "https://${local.host}"
  grpc_url_endpoint = "https://${local.grpc_host}"
  password_file     = "${local.tmp_dir}/argocd-password.val"
  argocd_values       = {
    global = {
      clusterType = var.cluster_type
    }
    openshift-gitops = {
      enabled = local.openshift_gitops
      createInstance = false
      controllerRbac = true
      subscription = {
        channel = local.version_re == "6" ? "preview" : "stable"
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
    username = "admin"
    password = data.local_file.argocd_password.content
    applicationMenu = !local.openshift_gitops
  }
  argocd_config_values_file = "${local.tmp_dir}/values-argocd-config.yaml"
  service_account_name = "${local.name}-argocd-application-controller"
}

resource null_resource cluster_version {
  triggers = {
    always = timestamp()
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/get-cluster-version.sh ${local.version_file}"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

module setup_clis {
  source = "github.com/cloud-native-toolkit/terraform-util-clis.git"

  clis = ["helm", "jq"]
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
    command = "kubectl delete job job-argocd -n ${local.app_namespace} || exit 0"

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
}

resource null_resource argocd_helm {
  depends_on = [null_resource.delete_argocd_helm]

  triggers = {
    namespace = var.app_namespace
    name = "argocd"
    chart = "${path.module}/charts/argocd"
    values_file_content = yamlencode(local.argocd_values)
    kubeconfig = var.cluster_config_file
    tmp_dir = local.tmp_dir
    bin_dir = local.bin_dir
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR = self.triggers.tmp_dir
      BIN_DIR = self.triggers.bin_dir
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR = self.triggers.tmp_dir
      BIN_DIR = self.triggers.bin_dir
    }
  }
}

resource null_resource wait-for-deployment {
  depends_on = [null_resource.argocd_helm]

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait-for-statefulset.sh ${var.app_namespace}"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

resource null_resource get_argocd_password {
  depends_on = [null_resource.argocd_helm]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/get-argocd-password.sh ${local.app_namespace} ${local.password_file} ${local.version_re}"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

data local_file argocd_password {
  depends_on = [null_resource.get_argocd_password]

  filename = local.password_file
}

resource null_resource argocd-config {
  depends_on = [null_resource.argocd_helm]

  triggers = {
    namespace = var.app_namespace
    name = "argocd-config"
    chart = "tool-config"
    repository = "https://charts.cloudnativetoolkit.dev"
    values_file_content = yamlencode(local.argocd_config_values)
    kubeconfig = var.cluster_config_file
    tmp_dir = local.tmp_dir
    bin_dir = local.bin_dir
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      REPO = self.triggers.repository
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR = self.triggers.tmp_dir
      BIN_DIR = self.triggers.bin_dir
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      REPO = self.triggers.repository
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR = self.triggers.tmp_dir
      BIN_DIR = self.triggers.bin_dir
    }
  }
}

resource null_resource get_argocd_host {
  depends_on = [null_resource.argocd_helm]

  triggers = {
    always = timestamp()
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/get-argocd-host.sh '${local.app_namespace}' '${local.host_file}'"

    environment = {
      KUBECONFIG = var.cluster_config_file
      BIN_DIR    = local.bin_dir
    }
  }
}

data local_file argocd_host {
  depends_on = [null_resource.get_argocd_host]

  filename = local.host_file
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
