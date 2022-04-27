#!/usr/bin/env bash

INPUT=$(tee)

export KUBECONFIG=$(echo "${INPUT}" | grep "kube_config" | sed -E 's/.*"kube_config": ?"([^"]*)".*/\1/g')
NAMESPACE=$(echo "${INPUT}" | grep "namespace" | sed -E 's/.*"namespace": ?"([^"]*)".*/\1/g')
BIN_DIR=$(echo "${INPUT}" | grep "bin_dir" | sed -E 's/.*"bin_dir": ?"([^"]*)".*/\1/g')

export PATH="${BIN_DIR}:${PATH}"

if ! command -v kubectl 1> /dev/null 2> /dev/null; then
  echo "kubectl cli not found" >&2
  exit 1
fi

if ! command -v jq 1> /dev/null 2> /dev/null; then
  echo "jq cli not found" >&2
  exit 1
fi

count=0
until kubectl get argocd -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; do
  if [[ $count -eq 20 ]]; then
    echo "{\"message\": \"Timed out waiting for argocd instance in namespace '${NAMESPACE}'\"}" >&2
    exit 1
  fi

  count=$((count + 1))
  sleep 30
done

ARGOCD_NAME=$(kubectl get argocd -n "${NAMESPACE}" -o json | jq -r '.items[] | .metadata.name' | head -n 1)

if [[ -z "${ARGOCD_NAME}" ]]; then
  echo "ArgoCD name not found in namespace ${NAMESPACE}" >&2
  exit 1
fi

# works with OCP 4.7+
SECRET_NAME="${ARGOCD_NAME}-cluster"

count=0
until kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; do
  if [[ $count -eq 20 ]]; then
    kubectl get secret -n "${NAMESPACE}" >&2
    exit 100
  fi

  count=$((count + 1))
  sleep 30
done

PASSWORD=$(kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" -o json | jq -r '.data["admin.password"] | @base64d')

LABEL="app.kubernetes.io/part-of=argocd"

count=0
while true; do
  if [[ $count -eq 20 ]]; then
    echo "{\"message\": \"Timed out waiting for route with label '${LABEL}' in namespace ${NAMESPACE}\"}" >&2
    exit 200
  fi

  count=$((count + 1))

  ROUTE_COUNT=$(kubectl get route -l ${LABEL} -n "${NAMESPACE}" -o json | jq '.items | length')
  if [[ "${ROUTE_COUNT}" -gt 0 ]]; then
    break
  fi
  sleep 30
done

HOST=$(kubectl get route -l ${LABEL} -n "${NAMESPACE}" -o json | jq -r '.items[0] | .spec.host')

echo "{\"host\": \"${HOST}\", \"password\": \"${PASSWORD}\"}"
