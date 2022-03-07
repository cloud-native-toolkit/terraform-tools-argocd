#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)

if [[ -f .kubeconfig ]]; then
  KUBECONFIG=$(cat .kubeconfig)
else
  KUBECONFIG="${PWD}/.kube/config"
fi
export KUBECONFIG

BIN_DIR=$(cat .bin_dir)

KUBECTL="${BIN_DIR}/kubectl"

CLUSTER_TYPE=$(cat ./terraform.tfvars | grep "cluster_type" | sed -E "s/.*=//g" | sed 's/"//g')

echo "listing directory contents"
ls -A

TOOLS_NAMESPACE=$(cat .namespace)
NAMESPACE=$(cat .argo-namespace)

ARGO_HOST=$(cat .argo-host)
ARGO_USERNAME=$(cat .argo-username)
ARGO_PASSWORD=$(cat .argo-password)

if [[ -z "${ARGO_HOST}" ]] || [[ -z "${ARGO_USERNAME}" ]] || [[ -z "${ARGO_PASSWORD}" ]]; then
  echo "ARGO_HOST, ARGO_USERNAME or ARGO_PASSWORD not provided (${ARGO_HOST}, ${ARGO_USERNAME}, ${ARGO_PASSWORD})"
  exit 1
fi

ARGOCD=$(command -v ${BIN_DIR}/argocd || command -v argocd)

if [[ -z "${NAME}" ]]; then
  NAME=$(echo "${NAMESPACE}" | sed "s/tools-//")
fi

echo "Verifying resources in ${NAMESPACE} namespace for module ${NAME}"

PODS=$(${KUBECTL} get -n "${NAMESPACE}" pods -o jsonpath='{range .items[*]}{.status.phase}{": "}{.kind}{"/"}{.metadata.name}{"\n"}{end}' | grep -v "Running" | grep -v "Succeeded")
POD_STATUSES=$(echo "${PODS}" | sed -E "s/(.*):.*/\1/g")
if [[ -n "${POD_STATUSES}" ]]; then
  echo "  Pods have non-success statuses: ${PODS}"
  exit 1
fi

set -e

if [[ "${CLUSTER_TYPE}" == "kubernetes" ]] || [[ "${CLUSTER_TYPE}" =~ iks.* ]]; then
  ENDPOINTS=$(${KUBECTL} get ingress -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{range .spec.rules[*]}{"https://"}{.host}{"\n"}{end}{end}')
else
  ENDPOINTS=$(${KUBECTL} get route -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.spec.host}{.spec.path}{"\n"}{end}')
fi

echo "Validating argo endpoints:"
echo "${ENDPOINTS}"

${KUBECTL} get route -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.spec.host}{.spec.path}{"\n"}{end}' | while read endpoint; do
  if [[ -n "${endpoint}" ]]; then
    ${SCRIPT_DIR}/waitForEndpoint.sh "https://${endpoint}" 10 10
  fi
done

echo "Endpoints validated"

if [[ "${CLUSTER_TYPE}" =~ ocp4 ]] && [[ -n "${CONSOLE_LINK_NAME}" ]]; then
  echo "Validating consolelink"
  if [[ $(${KUBECTL} get consolelink "${CONSOLE_LINK_NAME}" | wc -l) -eq 0 ]]; then
    echo "   ConsoleLink not found"
    exit 1
  fi
fi

echo "Logging in to argocd: ${ARGO_HOST} ${ARGO_PASSWORD}"
${ARGOCD} login "${ARGO_HOST}" --username "${ARGO_USERNAME}" --password "${ARGO_PASSWORD}" --insecure --grpc-web || exit 1

exit 0
