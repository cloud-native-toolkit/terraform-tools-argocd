#!/usr/bin/env bash

INPUT=$(tee)

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

export KUBECONFIG=$(echo "${INPUT}" | jq -r '.kube_config')
NAMESPACE=$(echo "${INPUT}" | jq -r '.namespace')
CLUSTER_TYPE="kubernetes"
if kubectl get route -A 1> /dev/null 2> /dev/null; then
  CLUSTER_TYPE="ocp"
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

if [[ -z "${HOST}" ]]; then
  count=0
  while true; do
    if [[ $count -eq 20 ]]; then
      echo "{\"message\": \"Timed out waiting for ingress/route with label '${LABEL}' in namespace ${NAMESPACE}\"}" >&2
      exit 200
    fi

    count=$((count + 1))

    if [[ "${CLUSTER_TYPE}" == "kubernetes" ]]; then
      INGRESS_COUNT=$(kubectl get ingress -l "${LABEL}" -n "${NAMESPACE}" -o json | jq '.items | length')
      if [[ "${INGRESS_COUNT}" -gt 0 ]]; then
        break
      fi
    else
      ROUTE_COUNT=$(kubectl get route -l "${LABEL}" -n "${NAMESPACE}" -o json | jq '.items | length')
      if [[ "${ROUTE_COUNT}" -gt 0 ]]; then
        break
      fi
    fi
    sleep 30
  done

  if [[ "${CLUSTER_TYPE}" == "kubernetes" ]]; then
    HOST=$(kubectl get ingress -l "${LABEL}" -n "${NAMESPACE}" -o json | jq -r '.items[0] | .spec.rules[0].host')
  else
    HOST=$(kubectl get route -l "${LABEL}" -n "${NAMESPACE}" -o json | jq -r '.items[0] | .spec.host')
  fi
fi

echo "{\"host\": \"${HOST}\", \"password\": \"${PASSWORD}\"}"
