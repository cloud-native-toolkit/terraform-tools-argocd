#!/usr/bin/env bash

NAMESPACE="$1"
OUTPUT_FILE="$2"

if [[ -z "${OUTPUT_FILE}" ]]; then
  echo "OUTPUT_FILE is required"
  exit 1
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

  ARGO_ROUTES=$(kubectl get route -l ${LABEL} -n "${NAMESPACE}" -o jsonpath='{range .items[]}{.metadata.name}{";"}{end}')
  if [[ -n "${ARGO_ROUTES}" ]]; then
    echo "Found route with label '${LABEL}' in namespace ${NAMESPACE}: ${ARGO_ROUTES}"
    break
  fi
  sleep 30
done

ARGO_HOSTS=$(kubectl get route -l ${LABEL} -n "${NAMESPACE}" -o jsonpath='{range .items[]}{.spec.host}{";"}{end}')
HOST=$(echo "${ARGO_HOSTS}" | sed -E 's/([^;]+);.*/\1/g')

echo -n "${HOST}" > "${OUTPUT_FILE}"
