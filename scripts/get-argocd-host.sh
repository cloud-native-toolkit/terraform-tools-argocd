#!/usr/bin/env bash

NAMESPACE="$1"
OUTPUT_FILE="$2"

if [[ -z "${OUTPUT_FILE}" ]]; then
  echo "OUTPUT_FILE is required"
  exit 1
fi

if [[ -z "${BIN_DIR}" ]]; then
  BIN_DIR="/usr/local/bin"
fi

mkdir -p "$(dirname "${OUTPUT_FILE}")"

LABEL="app.kubernetes.io/part-of=argocd"

count=0
while true; do
  if [[ $count -eq 20 ]]; then
    echo "Timed out waiting for route with label '${LABEL}' in namespace ${NAMESPACE}"
    exit 1
  fi

  count=$((count + 1))
  echo "Waiting for route with label '${LABEL}' in namespace ${NAMESPACE}"

  ROUTE_COUNT=$(kubectl get route -l ${LABEL} -n "${NAMESPACE}" -o json | "${BIN_DIR}/jq" '.items | length')
  if [[ "${ROUTE_COUNT}" -gt 0 ]]; then
    echo "Found route with label '${LABEL}' in namespace ${NAMESPACE}"
    break
  fi
  sleep 30
done

HOST=$(kubectl get route -l ${LABEL} -n "${NAMESPACE}" -o json | "${BIN_DIR}/jq" -r '.items[0] | .spec.host')

echo "Found ArgoCD host: ${HOST}"

echo -n "${HOST}" > "${OUTPUT_FILE}"
