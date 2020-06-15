#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)

set -e

CLUSTER_TYPE="$1"
NAMESPACE="$2"
INGRESS_SUBDOMAIN="$3"
NAME="$4"
TLS_SECRET_NAME="$5"

if [[ -z "${NAME}" ]]; then
  NAME=argocd
fi

if [[ -z "${TLS_SECRET_NAME}" ]]; then
  TLS_SECRET_NAME=$(echo "${INGRESS_SUBDOMAIN}" | sed -E "s/([^.]+).*/\1/g")
fi

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR=".tmp"
fi
mkdir -p "${TMP_DIR}"

if [[ -z ${PASSWORD_FILE} ]]; then
  PASSWORD_FILE="/dev/stdout"
fi

if [[ "${CLUSTER_TYPE}" == "kubernetes" ]]; then
  HOST="${NAME}-server-${NAMESPACE}.${INGRESS_SUBDOMAIN}"
  GRPC_HOST="${NAME}-server-grpc-${NAMESPACE}.${INGRESS_SUBDOMAIN}"
  ROUTE="false"
  INGRESS="true"
else
  ROUTE="true"
  INGRESS="false"
fi

YAML_FILE=${TMP_DIR}/argocd-instance-${NAME}.yaml

if [[ "${CLUSTER_TYPE}" == "kubernetes" ]]; then
  cat <<EOL > ${YAML_FILE}
apiVersion: argoproj.io/v1alpha1
kind: ArgoCD
metadata:
  name: ${NAME}
spec:
  server:
    grpc:
      host: ${GRPC_HOST}
      ingress: true
    host: ${HOST}
    ingress: true
    insecure: true
EOL
else
  cat <<EOL > ${YAML_FILE}
apiVersion: argoproj.io/v1alpha1
kind: ArgoCD
metadata:
  name: ${NAME}
spec:
  dex:
    image: quay.io/ablock/dex
    openShiftOAuth: true
    version: openshift-connector
  rbac:
    defaultPolicy: 'role:readonly'
    policy: |
      g, system:cluster-admins, role:admin
    scopes: '[groups]'
  server:
    route: ${ROUTE}
EOL
fi

echo "Applying argocd instance config:"
cat "${YAML_FILE}"

kubectl apply -f ${YAML_FILE} -n "${NAMESPACE}" || exit 1

"${SCRIPT_DIR}/wait-for-deployments.sh" "${NAMESPACE}" "${NAME}"

# For now, patch the ingress. Eventually the operator will handle this correctly
if [[ "${CLUSTER_TYPE}" == "kubernetes" ]]; then
  INGRESS_NAME=$(kubectl get ingress -n "${NAMESPACE}" -o=custom-columns=name:.metadata.name | grep -E "^argocd" | grep -vE "argocd.*grpc")
  kubectl patch ingress -n "${NAMESPACE}" "${INGRESS_NAME}" --type json \
    -p="[{\"op\": \"replace\", \"path\": \"/spec/tls/0/hosts/0\", value: \"${HOST}\"}, {\"op\": \"replace\", \"path\": \"/spec/tls/0/secretName\", \"value\": \"${TLS_SECRET_NAME}\"}]"

  GRPC_INGRESS_NAME=$(kubectl get ingress -n "${NAMESPACE}" -o=custom-columns=name:.metadata.name | grep -E "^argocd.*grpc")
  kubectl patch ingress -n "${NAMESPACE}" "${GRPC_INGRESS_NAME}" --type json \
    -p="[{\"op\": \"replace\", \"path\": \"/spec/tls/0/hosts/0\", value: \"${GRPC_HOST}\"}, {\"op\": \"replace\", \"path\": \"/spec/tls/0/secretName\", \"value\": \"${TLS_SECRET_NAME}\"}]"
fi

kubectl get secret argocd-cluster -n "${NAMESPACE}" -o jsonpath='{.data.admin\.password}' | base64 -d > "${PASSWORD_FILE}"
