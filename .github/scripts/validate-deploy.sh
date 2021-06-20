#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)

if [[ -f .kubeconfig ]]; then
  KUBECONFIG=$(cat .kubeconfig)
else
  KUBECONFIG="${PWD}/.kube/config"
fi
export KUBECONFIG

CLUSTER_TYPE=$(cat ./terraform.tfvars | grep "cluster_type" | sed -E "s/.*=//g" | sed 's/"//g')

TOOLS_NAMESPACE=$(cat .namespace)
NAMESPACE=$(cat .argo-namespace)
ARGO_HOST=$(cat .argo-host)
ARGO_USERNAME=$(cat .argo-username)
ARGO_PASSWORD=$(cat .argo-password)

if [[ -z "${ARGOCD_HOST}" ]] || [[ -z "${ARGOCD_USERNAME}" ]] || [[ -z "${ARGOCD_PASSWORD}" ]]; then
  echo "ARGOCD_HOST, ARGOCD_USERNAME or ARGOCD_PASSWORD not provided (${ARGOCD_HOST}, ${ARGO_USERNAME}, ${ARGOCD_PASSWORD})"
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
  ENDPOINTS=$(kubectl get route -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{"https://"}{.spec.host}{.spec.path}{"\n"}{end}')
fi

echo "Validating endpoints:"
echo "${ENDPOINTS}"

echo "${ENDPOINTS}" | while read endpoint; do
  if [[ -n "${endpoint}" ]]; then
    ${SCRIPT_DIR}/waitForEndpoint.sh "${endpoint}" 10 10
  fi
done

if [[ "${CLUSTER_TYPE}" =~ ocp4 ]] && [[ -n "${CONSOLE_LINK_NAME}" ]]; then
  echo "Validating consolelink"
  if [[ $(kubectl get consolelink "${CONSOLE_LINK_NAME}" | wc -l) -eq 0 ]]; then
    echo "   ConsoleLink not found"
    exit 1
  fi
fi

ARGOCD=$(command -v argocd || command -v ./argocd)

if [[ -n "${ARGOCD}" ]]; then
  VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
  curl -sSL -o ./argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
  chmod +x ./argocd
  ARGOCD="$(pwd -P)/argocd"
fi

echo "Logging in to argocd: ${ARGO_HOST}"
${ARGOCD} login "${ARGO_HOST}" --username "${ARGO_USERNAME}" --password "${ARGO_PASSWORD}" --insecure || exit 1

exit 0
