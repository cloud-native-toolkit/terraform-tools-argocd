#!/usr/bin/env bash

NAMESPACE="$1"
OUTPUT_FILE="$2"
OCP_MINOR_VERSION="$3"

if [[ -z "${OUTPUT_FILE}" ]]; then
  echo "OUTPUT_FILE is required"
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_FILE}")"

# works with OCP 4.7+
SECRET_NAME="openshift-gitops-cluster"

if [[ "${OCP_MINOR_VERSION}" == "6" ]]; then
  SECRET_NAME="argocd-cluster-cluster"
fi

count=0
until kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; do
  if [[ $count -eq 20 ]]; then
    echo "Timed out waiting for secret ${NAMESPACE}/${SECRET_NAME}"
    exit 1
  fi

  count=$((count + 1))
  echo "Waiting for secret ${NAMESPACE}/${SECRET_NAME}"
  kubectl get all -n "${NAMESPACE}"
  kubectl get secret -n "${NAMESPACE}"
  sleep 30
done

kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" -o jsonpath='{ .data.admin\.password }' | base64 -d > "${OUTPUT_FILE}"
