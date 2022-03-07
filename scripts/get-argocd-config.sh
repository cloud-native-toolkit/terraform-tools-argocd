#!/usr/bin/env bash

INPUT=$(tee)

export KUBECONFIG=$(echo "${INPUT}" | grep "kube_config" | sed -E 's/.*"kube_config": ?"([^"]*)".*/\1/g')
NAMESPACE=$(echo "${INPUT}" | grep "namespace" | sed -E 's/.*"namespace": ?"([^"]*)".*/\1/g')
OCP_MINOR_VERSION=$(echo "${INPUT}" | grep "minor_version" | sed -E 's/.*"minor_version": ?"([^"]*)".*/\1/g')
BIN_DIR=$(echo "${INPUT}" | grep "bin_dir" | sed -E 's/.*"bin_dir": ?"([^"]*)".*/\1/g')

KUBECTL="${BIN_DIR}/kubectl"
JQ="${BIN_DIR}/jq"

count=0
until ${KUBECTL} get argocd -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; do
  if [[ $count -eq 20 ]]; then
    echo "{\"message\": \"Timed out waiting for argocd instance in namespace '${NAMESPACE}'\"}" >&2
    exit 1
  fi

  count=$((count + 1))
  sleep 30
done

ARGOCD_NAME=$(${KUBECTL} get argocd -n "${NAMESPACE}" -o jsonpath='{.items[0].metadata.name}')

# works with OCP 4.7+
SECRET_NAME="${ARGOCD_NAME}-cluster"

#if [[ "${OCP_MINOR_VERSION}" == "6" ]]; then
#  SECRET_NAME="argocd-cluster-cluster"
#fi

count=0
until ${KUBECTL} get secret "${SECRET_NAME}" -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; do
  if [[ $count -eq 20 ]]; then
    SECRETS=$(${KUBECTL} get secret -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.metadata.name}{","}{end}')
    echo "{\"message\": \"Timed out waiting for secret '${SECRET_NAME}' in namespace '${NAMESPACE}'\", \"secrets\": \"${SECRETS}\"}" >&2
    exit 100
  fi

  count=$((count + 1))
  sleep 30
done

PASSWORD=$(${KUBECTL} get secret "${SECRET_NAME}" -n "${NAMESPACE}" -o jsonpath='{ .data.admin\.password }' | base64 -d)

LABEL="app.kubernetes.io/part-of=argocd"

count=0
while true; do
  if [[ $count -eq 20 ]]; then
    echo "{\"message\": \"Timed out waiting for route with label '${LABEL}' in namespace ${NAMESPACE}\"}" >&2
    exit 200
  fi

  count=$((count + 1))

  ROUTE_COUNT=$(${KUBECTL} get route -l ${LABEL} -n "${NAMESPACE}" -o json | ${JQ} '.items | length')
  if [[ "${ROUTE_COUNT}" -gt 0 ]]; then
    break
  fi
  sleep 30
done

HOST=$(${KUBECTL} get route -l ${LABEL} -n "${NAMESPACE}" -o json | ${JQ} -r '.items[0] | .spec.host')

echo "{\"host\": \"${HOST}\", \"password\": \"${PASSWORD}\"}"
