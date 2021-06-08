#!/usr/bin/env bash

NAMESPACE="$1"
OUTPUT_FILE="$2"

count=0
until kubectl get secret argocd-secret -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; do
  if [[ $count -eq 10 ]]; then
    echo "Timed out waiting for secret ${NAMESPACE}/argocd-secret"
    exit 1
  fi

  count=$((count + 1))
  echo "Waiting for secret ${NAMESPACE}/argocd-secret"
  kubectl get all -n "${NAMESPACE}"
  kubectl get secret -n "${NAMESPACE}"
  sleep 30
done

kubectl get secret argocd-secret -n "${NAMESPACE}" -o jsonpath='{ .data.admin\.password }' | base64 -d > "${OUTPUT_FILE}"
