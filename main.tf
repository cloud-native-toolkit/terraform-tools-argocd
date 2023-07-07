
locals {
  tmp_dir           = "${path.cwd}/.tmp"
  bin_dir           = data.clis_check.clis.bin_dir
  openshift_cluster = length(regexall("^openshift", data.external.get_operator_config.result.packageName)) > 0
  name              = local.openshift_cluster ? "openshift-gitops" : "argocd"
  operator_namespace = local.openshift_cluster ? "openshift-operators" : "operators"
  default_app_namespace = local.openshift_cluster ? "openshift-gitops" : "gitops"
  app_namespace     = var.app_namespace != "" ? var.app_namespace : local.default_app_namespace
  host              = data.external.argocd_config.result.host
  grpc_host         = data.external.argocd_config.result.host
  url_endpoint      = "https://${local.host}"
  grpc_url_endpoint = "https://${local.grpc_host}"
  created_by        = "argo-${random_string.random.result}"
  disable_default_instance = true
  disable_dex = !local.openshift_cluster
  argocd_values       = {
    global = {
      clusterType = var.cluster_type
      olmNamespace = data.external.get_operator_config.result.catalogSourceNamespace
      operatorNamespace = local.operator_namespace
      dummy = var.dummy
    }
    openshift-gitops = {
      enabled = true
      createInstance = false
      controllerRbac = true
      subscription = {
        source  = data.external.get_operator_config.result.catalogSource
        name    = data.external.get_operator_config.result.packageName
        channel = data.external.get_operator_config.result.defaultChannel
      }
      createdBy = local.created_by
      disableDefaultInstance = local.disable_default_instance
      disableDex = local.disable_dex
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

data clis_check clis {
  clis = ["helm", "jq", "oc", "kubectl"]
}

data external get_operator_config {
  program = ["bash", "${path.module}/scripts/get-operator-config.sh"]

  query = {
    kube_config   = var.cluster_config_file
    olm_namespace = var.olm_namespace
    bin_dir       = local.bin_dir
  }
}

data external check_for_operator {
  program = ["bash", "${path.module}/scripts/check-for-operator.sh"]

  query = {
    kube_config = var.cluster_config_file
    namespace   = local.operator_namespace
    name        = data.external.get_operator_config.result.packageName
    bin_dir     = local.bin_dir
    created_by  = local.created_by
  }
}

resource "random_string" "random" {
  length           = 16
  lower            = true
  numeric          = true
  upper            = false
  special          = false
}

resource null_resource argocd_operator_helm {

  triggers = {
    namespace = local.operator_namespace
    name = "argocd"
    chart = "${path.module}/charts/argocd"
    values_file_content = nonsensitive(yamlencode(local.argocd_values))
    kubeconfig = var.cluster_config_file
    tmp_dir = local.tmp_dir
    bin_dir = local.bin_dir
    created_by = local.created_by
    skip = data.external.check_for_operator.result.exists
    subscription_name = data.external.get_operator_config.result.packageName
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

    command = "${path.module}/scripts/destroy-operator.sh ${self.triggers.namespace} ${self.triggers.name} ${self.triggers.chart} ${self.triggers.subscription_name}"

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

module app_namespace {
  depends_on = [null_resource.argocd_operator_helm]
  source = "github.com/cloud-native-toolkit/terraform-k8s-namespace.git"

  cluster_config_file_path = var.cluster_config_file
  name                     = local.app_namespace
}

resource null_resource wait_for_namespace {
  provisioner "local-exec" {
    command = "${path.module}/scripts/wait-for-namespace.sh ${module.app_namespace.name}"

    environment = {
      BIN_DIR = local.bin_dir
      KUBECONFIG = var.cluster_config_file
    }
  }
}

data external check_for_instance {
  depends_on = [null_resource.wait_for_crd, null_resource.wait_for_namespace]

  program = ["bash", "${path.module}/scripts/check-for-instance.sh"]

  query = {
    namespace = module.app_namespace.name
    kube_config = var.cluster_config_file
    bin_dir = local.bin_dir
    created_by = local.created_by
  }
}

resource null_resource argocd_instance_helm {
  depends_on = [null_resource.wait_for_crd, null_resource.wait_for_namespace]

  triggers = {
    namespace = module.app_namespace.name
    name = module.app_namespace.name
    chart = "${path.module}/charts/argocd-instance"
    kubeconfig = var.cluster_config_file
    tmp_dir = local.tmp_dir
    bin_dir = local.bin_dir
    created_by = local.created_by
    skip = data.external.check_for_instance.result.exists
    values_file_content = nonsensitive(yamlencode({
      openshift-gitops-instance = {
        enabled = local.openshift_cluster
        disableDefaultInstance = local.disable_default_instance
        createdBy = local.created_by
        dummy = var.dummy
      }
      argocd-instance = {
        enabled = !local.openshift_cluster
        argocd = {
          spec = {
            server = {
              host = "${local.name}.${var.ingress_subdomain}"
              ingress = {
                enabled = var.ingress_subdomain != ""
                annotations = var.tls_secret_name != null && var.tls_secret_name != "" ? {
                  "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
                  "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
                } : {}
                tls = var.tls_secret_name != null && var.tls_secret_name != "" ? [{
                  hosts = ["${local.name}.${var.ingress_subdomain}"]
                  secretName = var.tls_secret_name
                }] : []
              }
            }
          }
        }
      }
    }))
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

resource null_resource argocd_permissions {
  depends_on = [null_resource.argocd_instance_helm]

  triggers = {
    namespace = local.operator_namespace
    name = "${local.operator_namespace}-rbac"
    chart = "rbac"
    kubeconfig = var.cluster_config_file
    tmp_dir = local.tmp_dir
    bin_dir = local.bin_dir
    created_by = local.created_by
    skip = data.external.check_for_instance.result.exists
    values_file_content = yamlencode({
      rules = [{
        apiGroups = ["*"]
        resources = ["*"]
        verbs = ["*"]
      }]
      serviceAccount = {
        namespace = module.app_namespace.name
      }
    })
    repo = "https://charts.cloudnativetoolkit.dev/"
    version = "0.2.0"
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
      REPO = self.triggers.repo
      VERSION = self.triggers.version
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
      REPO = self.triggers.repo
      VERSION = self.triggers.version
    }
  }
}

resource null_resource wait_for_resources {
  depends_on = [null_resource.argocd_instance_helm, null_resource.argocd_permissions]

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait-for-resources.sh ${module.app_namespace.name} 'app.kubernetes.io/part-of=argocd'"

    environment = {
      BIN_DIR = local.bin_dir
      KUBECONFIG = var.cluster_config_file
    }
  }
}

data external argocd_config {
  depends_on = [null_resource.wait_for_resources]

  program = ["bash", "${path.module}/scripts/get-argocd-config.sh"]

  query = {
    namespace = module.app_namespace.name
    kube_config = var.cluster_config_file
    bin_dir = local.bin_dir
  }
}

resource null_resource argocd_config {
  depends_on = [null_resource.wait_for_resources]

  triggers = {
    namespace = module.app_namespace.name
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
