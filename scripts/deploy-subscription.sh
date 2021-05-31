#!/usr/bin/env bash

CLUSTER_TYPE="$1"
OPERATOR_NAMESPACE="$2"
OLM_NAMESPACE="$3"
CLUSTER_VERSION="$4"

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR=".tmp"
fi
mkdir -p "${TMP_DIR}"

if [[ -z "${OLM_NAMESPACE}" ]]; then
  if [[ "${CLUSTER_TYPE}" == "ocp4" ]]; then
    OLM_NAMESPACE="openshift-marketplace"
  else
    OLM_NAMESPACE="olm"
  fi
fi

if [[ "${CLUSTER_TYPE}" == "ocp4" ]]; then
  if [[ "${CLUSTER_VERSION}" =~ ^4.6 ]]; then
    SOURCE="redhat-operators"
  else
    SOURCE="community-operators"
  fi
else
  SOURCE="operatorhubio-catalog"
fi

if [[ "${CLUSTER_VERSION}" =~ ^4.[6-9] ]]; then
  NAME="openshift-gitops-operator"
  CHANNEL="preview"
  OPERATOR_NAMESPACE="openshift-operators"
else
  NAME="argocd-operator"
  CHANNEL="alpha"
fi

YAML_FILE=${TMP_DIR}/argocd-subscription.yaml

cat <<EOL > ${YAML_FILE}
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${NAME}
spec:
  channel: ${CHANNEL}
  installPlanApproval: Automatic
  name: ${NAME}
  source: ${SOURCE}
  sourceNamespace: ${OLM_NAMESPACE}
EOL

set -e

echo "Installing argocd operator into ${OPERATOR_NAMESPACE} namespace"
kubectl apply -f ${YAML_FILE} -n "${OPERATOR_NAMESPACE}"

set +e

sleep 2
count=0
until kubectl get crd/argocds.argoproj.io 1>/dev/null 2>/dev/null; do
  if [[ $count -eq 10 ]]; then
    echo "Timed out waiting for ArgoCD CRD to be installed"
    exit 1
  fi

  echo "Waiting for ArgoCD CRD to be installed"
  sleep 15

  count=$((count+1))
done

count=0
until kubectl get csv -n "${OPERATOR_NAMESPACE}" | grep -q "${NAME}"; do
  if [[ $count -eq 10 ]]; then
    echo "Timed out waiting for ArgoCD CSV install to be started in ${OPERATOR_NAMESPACE}"
    exit 1
  fi

  echo "Waiting for ArgoCD CSV install to be started in ${OPERATOR_NAMESPACE}"
  sleep 15
done

CSV_NAME=$(kubectl get csv -n "${OPERATOR_NAMESPACE}" -o custom-columns=name:.metadata.name | grep "${NAME}")

count=0
until [[ $(kubectl get csv -n "${OPERATOR_NAMESPACE}" "${CSV_NAME}" -o jsonpath='{.status.phase}') == "Succeeded" ]]; do
  if [[ $count -eq 10 ]]; then
    echo "Timed out waiting for ArgoCD CSV to be successfully installed in ${OPERATOR_NAMESPACE}"
    exit 1
  fi

  echo "Waiting for ArgoCD CSV to be successfully installed in ${OPERATOR_NAMESPACE}"
  sleep 15
done
