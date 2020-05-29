#!/usr/bin/env bash

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
  HOST="${NAME}-${NAMESPACE}.${INGRESS_SUBDOMAIN}"
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
      host: grpc.${HOST}
      ingress: true
    host: ${HOST}
    ingress: true
    insecure: true
EOL
#  tls:
#    ca:
#      secretName: ${TLS_SECRET_NAME}
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

kubectl apply -f ${YAML_FILE} -n "${NAMESPACE}" || exit 1

DEPLOYMENT="${NAME}-server"

count=0
until kubectl get deployment/${DEPLOYMENT} -n ${NAMESPACE} 1> /dev/null 2> /dev/null; do
  if [[ ${count} -eq 12 ]]; then
    echo "Timed out waiting for deployment/${DEPLOYMENT} to start"
    exit 1
  else
    count=$((count + 1))
  fi

  echo "Waiting for deployment/${DEPLOYMENT} to start"
  sleep 10
done

kubectl rollout status deployment/${DEPLOYMENT} -n "${NAMESPACE}"

kubectl get secret argocd-cluster -n "${NAMESPACE}" -o jsonpath='{.data.admin\.password}' | base64 -d > "${PASSWORD_FILE}"
