#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)

if [[ -f .kubeconfig ]]; then
  KUBECONFIG=$(cat .kubeconfig)
else
  KUBECONFIG="${PWD}/.kube/config"
fi
export KUBECONFIG

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

ARGOCD=$(command -v argocd || command -v ./argocd)

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

echo "Endpoints validated"

if [[ "${CLUSTER_TYPE}" =~ ocp4 ]] && [[ -n "${CONSOLE_LINK_NAME}" ]]; then
  echo "Validating consolelink"
  if [[ $(kubectl get consolelink "${CONSOLE_LINK_NAME}" | wc -l) -eq 0 ]]; then
    echo "   ConsoleLink not found"
    exit 1
  fi
fi

if [[ -z "${ARGOCD}" ]]; then
  VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
  curl -sSL -o ./argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
  chmod +x ./argocd
  ARGOCD="$(pwd -P)/argocd"
fi

echo "Logging in to argocd: ${ARGO_HOST}"
${ARGOCD} login "${ARGO_HOST}" --username "${ARGO_USERNAME}" --password "${ARGO_PASSWORD}" --insecure --grpc-web
${ARGOCD} login "cluster-openshift-gitops.toolkit-dev-ocp47-2ab66b053c14936810608de9a1deac9c-0000.us-east.containers.appdomain.cloud" --username "${ARGO_USERNAME}" --password "${ARGO_PASSWORD}" --insecure --grpc-web

echo "Validating argocd-access secret"
SECRET_PASSWORD=$(kubectl get secret -n "${TOOLS_NAMESPACE}" argocd-access -o jsonpath='{.data.ARGOCD_PASSWORD}' | base64 -d)

if [[ "${ARGO_PASSWORD}" != "${SECRET_PASSWORD}" ]]; then
  echo "Password in secret does not match: ${SECRET_PASSWORD} != ${ARGO_PASSWORD}"
  exit 1
fi

exit 0
