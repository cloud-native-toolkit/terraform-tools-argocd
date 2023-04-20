# ArgoCD terraform module

![Latest release](https://img.shields.io/github/v/release/ibm-garage-cloud/terraform-tools-argocd?sort=semver) ![Verify and release module](https://github.com/ibm-garage-cloud/terraform-tools-argocd/workflows/Verify%20and%20release%20module/badge.svg)

Installs ArgoCD in the cluster via the operator. On OpenShift the module will also set up a route and
enable OpenShift Auth. On Kubernetes, an ingress will be created.


## Software dependencies

The module depends on the following software components:

- terraform v0.15

## Module dependencies

- Cluster
- OLM

## Example usage

See [example/](example) folder for full example usage

```hcl-terraform
module "argocd" {
  source = "github.com/ibm-garage-cloud/terraform-tools-argocd.git"

  cluster_config_file = module.cluster.config_file_path
  cluster_type        = module.cluster.platform.type_code
  olm_namespace       = module.olm.olm_namespace
  operator_namespace  = module.olm.target_namespace
  name                = "argocd"
}
```
