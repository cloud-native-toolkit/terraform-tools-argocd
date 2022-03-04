#!/usr/bin/env bash

INPUT=$(tee)

export KUBECONFIG=$(echo "${INPUT}" | grep "kube_config" | sed -E 's/.*"kube_config": ?"([^"]*)".*/\1/g')
NAMESPACE=$(echo "${INPUT}" | grep "namespace" | sed -E 's/.*"namespace": ?"([^"]*)".*/\1/g')
OCP_MINOR_VERSION=$(echo "${INPUT}" | grep "minor_version" | sed -E 's/.*"minor_version": ?"([^"]*)".*/\1/g')
BIN_DIR=$(echo "${INPUT}" | grep "bin_dir" | sed -E 's/.*"bin_dir": ?"([^"]*)".*/\1/g')

# works with OCP 4.7+
SECRET_NAME="openshift-gitops-cluster"

if [[ "${OCP_MINOR_VERSION}" == "6" ]]; then
  SECRET_NAME="argocd-cluster-cluster"
fi

count=0
until kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; do
  if [[ $count -eq 20 ]]; then
    exit 100
  fi

  count=$((count + 1))
  sleep 30
done

PASSWORD=$(kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" -o jsonpath='{ .data.admin\.password }' | base64 -d)

LABEL="app.kubernetes.io/part-of=argocd"

count=0
while true; do
  if [[ $count -eq 20 ]]; then
    echo "{\"message\": \"Timed out waiting for route with label '${LABEL}' in namespace ${NAMESPACE}\"}"
    exit 200
  fi

  count=$((count + 1))

  ROUTE_COUNT=$(kubectl get route -l ${LABEL} -n "${NAMESPACE}" -o json | "${BIN_DIR}/jq" '.items | length')
  if [[ "${ROUTE_COUNT}" -gt 0 ]]; then
    break
  fi
  sleep 30
done

HOST=$(kubectl get route -l ${LABEL} -n "${NAMESPACE}" -o json | "${BIN_DIR}/jq" -r '.items[0] | .spec.host')

echo "{\"host\": \"${HOST}\", \"password\": \"${PASSWORD}\"}"
