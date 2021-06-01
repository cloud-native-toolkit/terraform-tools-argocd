#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)

set -e

CLUSTER_TYPE="$1"
NAMESPACE="$2"
INGRESS_SUBDOMAIN="$3"
NAME="$4"
CLUSTER_VERSION="$5"
TLS_SECRET_NAME="$6"

if [[ -z "${NAME}" ]]; then
  NAME=argocd-cluster
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

if [[ "${CLUSTER_VERSION}" =~ ^4.[6-9] ]]; then
  NAMESPACE="openshift-gitops"
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
      ingress:
        enabled: true
        path: /
        tls:
          - secretName: ${TLS_SECRET_NAME}
            hosts:
              - ${GRPC_HOST}
    host: ${HOST}
    ingress:
      enabled: true
      path: /
      tls:
        - secretName: ${TLS_SECRET_NAME}
          hosts:
            - ${HOST}
    insecure: true
EOL
elif kubectl get argocd "${NAME}" -n "${NAMESPACE}"; then
  cat <<EOL > ${YAML_FILE}
apiVersion: user.openshift.io/v1
kind: Group
metadata:
  name: argocd-admins
users: []
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
    defaultPolicy: 'role:admin'
    policy: |
      g, argocd-admins, role:admin
    scopes: '[groups]'
  server:
    route: 
      enabled: ${ROUTE}
      tls:
          termination: passthrough
          insecureEdgeTerminationPolicy: Redirect
      wildcardPolicy: None
---
apiVersion: user.openshift.io/v1
kind: Group
metadata:
  name: argocd-admins
users: []
EOL
fi

echo "Applying argocd instance config:"
cat "${YAML_FILE}"

kubectl apply -f ${YAML_FILE} -n "${NAMESPACE}" || exit 1

if [[ "${CLUSTER_VERSION}" =~ ^4.6 ]]; then

  PATCH_FILE="${TMP_DIR}/argocd-instance-patch.yaml"
  cat <<EOL > ${PATCH_FILE}
spec:
  dex:
    image: quay.io/ablock/dex
    openShiftOAuth: true
    version: openshift-connector
  rbac:
    defaultPolicy: 'role:admin'
    policy: |
      g, argocd-admins, role:admin
    scopes: '[groups]'
  server:
    route:
      enabled: ${ROUTE}
      tls:
          termination: passthrough
          insecureEdgeTerminationPolicy: Redirect
      wildcardPolicy: None
EOL

  echo "Patching argocd instance: ${NAMESPACE}/${NAME}"
  echo "oc patch argocd ${NAME} -n '${NAMESPACE}' --type merge --patch xxx"
  echo "Patch file: "
  cat "${PATCH_FILE}"

#  oc patch argocd ${NAME} -n "${NAMESPACE}" --type merge -p "$(cat ${PATCH_FILE})"
  echo "Skipping patch for now"
fi

echo "Waiting for deployments"
"${SCRIPT_DIR}/wait-for-deployments.sh" "${NAMESPACE}" "${NAME}"

kubectl get secret argocd-cluster -n "${NAMESPACE}" -o jsonpath='{.data.admin\.password}' | base64 -d > "${PASSWORD_FILE}"
