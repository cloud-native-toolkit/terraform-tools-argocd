
locals {
  tmp_dir           = "${path.cwd}/.tmp"
  bin_dir           = module.setup_clis.bin_dir
  name              = "openshift-gitops"
  app_namespace     = "openshift-gitops"
  host              = data.external.argocd_config.result.host
  grpc_host         = data.external.argocd_config.result.host
  url_endpoint      = "https://${local.host}"
  grpc_url_endpoint = "https://${local.grpc_host}"
  created_by        = "argo-${random_string.random.result}"
  argocd_values       = {
    global = {
      clusterType = var.cluster_type
      operatorNamespace = var.operator_namespace
    }
    openshift-gitops = {
      enabled = true
      createInstance = false
      controllerRbac = true
      subscription = {
        channel = "stable"
      }
      createdBy = local.created_by
    }
  }
  argocd_values_file = "${local.tmp_dir}/values-argocd.yaml"
  argocd_config_values = {
    name = "ArgoCD"
    username = "admin"
    password = data.external.argocd_config.result.password
    url = "https://${data.external.argocd_config.result.host}"
    applicationMenu = false
    enableConsoleLink = false
  }
  argocd_config_values_file = "${local.tmp_dir}/values-argocd-config.yaml"
  service_account_name = "${local.name}-argocd-application-controller"
}

module setup_clis {
  source = "cloud-native-toolkit/clis/util"
  version = "1.16.4"

  clis = ["helm", "jq", "oc", "kubectl"]
}

data external check_for_operator {
  program = ["bash", "${path.module}/scripts/check-for-operator.sh"]

  query = {
    kube_config = var.cluster_config_file
    namespace = "openshift-operators"
    bin_dir = module.setup_clis.bin_dir
    created_by = local.created_by
  }
}

resource "random_string" "random" {
  length           = 16
  lower            = true
  number           = true
  upper            = false
  special          = false
}

resource null_resource argocd_operator_helm {

  triggers = {
    namespace = var.operator_namespace
    name = "argocd"
    chart = "${path.module}/charts/argocd"
    values_file_content = yamlencode(local.argocd_values)
    kubeconfig = var.cluster_config_file
    tmp_dir = local.tmp_dir
    bin_dir = local.bin_dir
    created_by = local.created_by
    skip = data.external.check_for_operator.result.exists
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR = self.triggers.tmp_dir
      BIN_DIR = self.triggers.bin_dir
      CREATED_BY = self.triggers.created_by
      SKIP = self.triggers.skip
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy-operator.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR = self.triggers.tmp_dir
      BIN_DIR = self.triggers.bin_dir
      CREATED_BY = self.triggers.created_by
      SKIP = self.triggers.skip
    }
  }
}

resource null_resource wait_for_crd {
  depends_on = [null_resource.argocd_operator_helm]

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait-for-crd.sh"

    environment = {
      KUBECONFIG = var.cluster_config_file
      TMP_DIR = local.tmp_dir
      BIN_DIR = local.bin_dir
    }
  }
}

resource null_resource wait-for-namespace {
  depends_on = [null_resource.argocd_operator_helm]

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait-for-namespace.sh ${var.app_namespace}"

    environment = {
      BIN_DIR = module.setup_clis.bin_dir
      KUBECONFIG = var.cluster_config_file
    }
  }
}

data external check_for_instance {
  depends_on = [null_resource.wait_for_crd, null_resource.wait-for-namespace]

  program = ["bash", "${path.module}/scripts/check-for-instance.sh"]

  query = {
    namespace = var.app_namespace
    kube_config = var.cluster_config_file
    bin_dir = module.setup_clis.bin_dir
    created_by = local.created_by
  }
}

resource null_resource argocd_instance_helm {
  depends_on = [null_resource.wait_for_crd, null_resource.wait-for-namespace]

  triggers = {
    namespace = var.app_namespace
    name = var.app_namespace
    chart = "${path.module}/charts/argocd-instance"
    kubeconfig = var.cluster_config_file
    tmp_dir = local.tmp_dir
    bin_dir = local.bin_dir
    created_by = local.created_by
    skip = data.external.check_for_instance.result.exists
    values_file_content = yamlencode({
      openshift-gitops-instance = {
        createdBy = local.created_by
      }
    })
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR = self.triggers.tmp_dir
      BIN_DIR = self.triggers.bin_dir
      CREATED_BY = self.triggers.created_by
      SKIP = self.triggers.skip
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
      CREATED_BY = self.triggers.created_by
      SKIP = self.triggers.skip
    }
  }
}

resource null_resource wait-for-resources {
  depends_on = [null_resource.argocd_instance_helm]

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait-for-resources.sh ${var.app_namespace} 'app.kubernetes.io/part-of=argocd'"

    environment = {
      BIN_DIR = module.setup_clis.bin_dir
      KUBECONFIG = var.cluster_config_file
    }
  }
}

data external argocd_config {
  depends_on = [null_resource.wait-for-resources]

  program = ["bash", "${path.module}/scripts/get-argocd-config.sh"]

  query = {
    namespace = var.app_namespace
    kube_config = var.cluster_config_file
    bin_dir = module.setup_clis.bin_dir
  }
}

resource null_resource argocd-config {
  depends_on = [null_resource.wait-for-resources]

  triggers = {
    namespace = var.app_namespace
    name = "argocd-config"
    chart = "tool-config"
    repository = "https://charts.cloudnativetoolkit.dev"
    values_file_content = yamlencode(local.argocd_config_values)
    kubeconfig = var.cluster_config_file
    tmp_dir = local.tmp_dir
    bin_dir = local.bin_dir
    skip = data.external.check_for_instance.result.exists
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-helm.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      REPO = self.triggers.repository
      VALUES_FILE_CONTENT = self.triggers.values_file_content
      TMP_DIR = self.triggers.tmp_dir
      BIN_DIR = self.triggers.bin_dir
      SKIP = self.triggers.skip
      VERSION = "0.13.0"
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
      SKIP = self.triggers.skip
    }
  }
}
