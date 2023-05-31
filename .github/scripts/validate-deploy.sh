#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)

if [[ -f .kubeconfig ]]; then
  KUBECONFIG=$(cat .kubeconfig)
else
  KUBECONFIG="${PWD}/.kube/config"
fi
export KUBECONFIG

BIN_DIR=$(cat .bin_dir)

if [[ -n "${BIN_DIR}" ]]; then
  export PATH="${BIN_DIR}:${PATH}"
fi

if ! command -v kubectl 1> /dev/null 2> /dev/null; then
  echo "kubectl cli not found" >&2
  exit 1
fi

if ! command -v argocd 1> /dev/null 2> /dev/null; then
  echo "argocd cli not found" >&2
  exit 1
fi

CLUSTER_TYPE=$(cat ./.cluster_type)

echo "Cluster type: $CLUSTER_TYPE"

echo "listing directory contents"
ls -A

NAMESPACE=$(cat .namespace)

ARGO_HOST=$(cat .argo-host)
ARGO_USERNAME=$(cat .argo-username)
ARGO_PASSWORD=$(cat .argo-password)

if [[ -z "${ARGO_HOST}" ]] || [[ -z "${ARGO_USERNAME}" ]] || [[ -z "${ARGO_PASSWORD}" ]]; then
  echo "ARGO_HOST, ARGO_USERNAME or ARGO_PASSWORD not provided (${ARGO_HOST}, ${ARGO_USERNAME}, ${ARGO_PASSWORD})"
  exit 1
fi

if [[ -z "${NAME}" ]]; then
  NAME=$(echo "${NAMESPACE}" | sed "s/tools-//")
fi

echo "Verifying resources in ${NAMESPACE} namespace for module ${NAME}"

PODS=$(kubectl get -n "${NAMESPACE}" pods -o jsonpath='{range .items[*]}{.status.phase}{": "}{.kind}{"/"}{.metadata.name}{"\n"}{end}' | grep -v "Running" | grep -v "Succeeded")
POD_STATUSES=$(echo "${PODS}" | sed -E "s/(.*):.*/\1/g")
if [[ -n "${POD_STATUSES}" ]]; then
  echo "  Pods have non-success statuses: ${PODS}"
  exit 1
fi

set -e

if [[ "${CLUSTER_TYPE}" == "kubernetes" ]] || [[ "${CLUSTER_TYPE}" =~ iks.* ]]; then
  ENDPOINTS=$(kubectl get ingress -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{range .spec.rules[*]}{"https://"}{.host}{"\n"}{end}{end}')
else
  ENDPOINTS=$(kubectl get route -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.spec.host}{.spec.path}{"\n"}{end}')
fi

echo "Validating argo endpoints:"
echo "${ENDPOINTS}"

if [[ "${CLUSTER_TYPE}" == "kubernetes" ]] || [[ "${CLUSTER_TYPE}" =~ iks.* ]]; then
  kubectl get ingress -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{range .spec.rules[*]}{.host}{"\n"}{end}{end}' | while read endpoint; do
    if [[ -n "${endpoint}" ]]; then
      "${SCRIPT_DIR}/waitForEndpoint.sh" "https://${endpoint}" 30 30 "${NAMESPACE}"
    fi
  done
else
  kubectl get route -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.spec.host}{.spec.path}{"\n"}{end}' | while read endpoint; do
    if [[ -n "${endpoint}" ]]; then
      "${SCRIPT_DIR}/waitForEndpoint.sh" "https://${endpoint}" 30 30 "${NAMESPACE}"
    fi
  done
fi

echo "Endpoints validated"

if [[ "${CLUSTER_TYPE}" =~ ocp4 ]] && [[ -n "${CONSOLE_LINK_NAME}" ]]; then
  echo "Validating consolelink"
  if [[ $(kubectl get consolelink "${CONSOLE_LINK_NAME}" | wc -l) -eq 0 ]]; then
    echo "   ConsoleLink not found"
    exit 1
  fi
fi

echo "Logging in to argocd: ${ARGO_HOST} ${ARGO_PASSWORD}"
argocd login "${ARGO_HOST}" --username "${ARGO_USERNAME}" --password "${ARGO_PASSWORD}" --insecure --grpc-web || exit 1

if ! kubectl get configmap -n "${NAMESPACE}" argocd-config 1> /dev/null 2> /dev/null; then
  echo "ConfigMap not found: ${NAMESPACE}/argocd-config" >&2
  kubectl get configmap -n "${NAMESPACE}"
  exit 1
fi

CONFIG_URL=$(kubectl get configmap -n "${NAMESPACE}" argocd-config -o json | jq -r '.data.url')

if [[ "https://${ARGO_HOST}" != "${CONFIG_URL}" ]]; then
  echo "The config url does not match argo url: config_url=${CONFIG_URL}, argo_url=https://${ARGO_HOST}" >&2
  exit 1
fi

exit 0
