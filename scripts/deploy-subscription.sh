#!/usr/bin/env sh

CLUSTER_TYPE="$1"
OPERATOR_NAMESPACE="$2"
OLM_NAMESPACE="$3"
OPERATOR_VERSION="$4"

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR=".tmp"
fi
mkdir -p "${TMP_DIR}"

if [[ "${CLUSTER_TYPE}" == "ocp4" ]]; then
  SOURCE="community-operators"
else
  SOURCE="operatorhubio-catalog"
fi

if [[ -z "${OLM_NAMESPACE}" ]]; then
  if [[ "${CLUSTER_TYPE}" == "ocp4" ]]; then
    OLM_NAMESPACE="openshift-marketplace"
  else
    OLM_NAMESPACE="olm"
  fi
fi

if [[ -z "${OPERATOR_VERSION}" ]]; then
  OPERATOR_VERSION="v0.0.9"
fi

YAML_FILE=${TMP_DIR}/argocd-subscription.yaml

cat <<EOL > ${YAML_FILE}
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ${OPERATOR_NAMESPACE}-operatorgroup
  annotations:
    olm.providedAPIs: AppProject.v1alpha1.argoproj.io,Application.v1alpha1.argoproj.io,ArgoCD.v1alpha1.argoproj.io,ArgoCDExport.v1alpha1.argoproj.io
spec:
  targetNamespaces:
  - ${OPERATOR_NAMESPACE}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: argocd-operator
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: argocd-operator
  source: $SOURCE
  sourceNamespace: $OLM_NAMESPACE
EOL

set -e

echo "Installing argocd operator into ${OPERATOR_NAMESPACE} namespace"
kubectl apply -f ${YAML_FILE} -n "${OPERATOR_NAMESPACE}"

set +e

sleep 2
until kubectl get crd/argocds.argoproj.io 1>/dev/null 2>/dev/null; do
  echo "Waiting for ArgoCD operator to install"
  sleep 30
done
