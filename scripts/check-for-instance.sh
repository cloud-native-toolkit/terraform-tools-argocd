#!/usr/bin/env bash

INPUT=$(tee)

export KUBECONFIG=$(echo "${INPUT}" | grep "kube_config" | sed -E 's/.*"kube_config": ?"([^"]*)".*/\1/g')
NAMESPACE=$(echo "${INPUT}" | grep "namespace" | sed -E 's/.*"namespace": ?"([^"]*)".*/\1/g')
BIN_DIR=$(echo "${INPUT}" | grep "bin_dir" | sed -E 's/.*"bin_dir": ?"([^"]*)".*/\1/g')
CREATED_BY=$(echo "${INPUT}" | grep "created_by" | sed -E 's/.*"created_by": ?"([^"]*)".*/\1/g')

export PATH="${BIN_DIR}:${PATH}"

if ! command -v oc 1> /dev/null 2> /dev/null; then
  echo "oc cli not found" >&2
  exit 1
fi

if ! command -v jq 1> /dev/null 2> /dev/null; then
  echo "jq cli not found" >&2
  exit 1
fi

if [[ "${NAMESPACE}" == "openshift-gitops" ]]; then
  echo '{"exists": "false"}'
  exit 0
fi

## check for argocd instance
ARGOCD_INSTANCE=$(oc get argocd -n "${NAMESPACE}" -o json | jq -r '.items[] | .metadata.name' | head -1)
ARGOCD_CREATED_BY=$(oc get argocd -n "${NAMESPACE}" -o json | jq -r '.items[] | .metadata.labels["created-by"] // empty')

if [[ "${ARGOCD_CREATED_BY}" == "${CREATED_BY}" ]]; then
  ## This will happen when terraform plan is run after the module has already been applied (i.e. destroy or apply additional content)
  ## We want to preserve the state so it doesn't trigger the content to be re-applied or for destroy to be skipped
  echo '{"exists": "false"}'
  exit 0
elif [[ -n "${ARGOCD_INSTANCE}" ]]; then
  echo '{"exists": "true"}'
  exit 0
else
  echo '{"exists": "false"}'
  exit 0
fi
