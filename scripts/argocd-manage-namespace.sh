#!/usr/bin/env bash

TARGET="$1"
ARGOCD_NAMESPACE="$2"

if [[ -z "${TARGET}" ]] || [[ -z "${ARGOCD_NAMESPACE}" ]]; then
  echo "usage: argocd-manage-namespace.sh {TARGET} {ARGOCD_NAMESPACE}" >&2
  exit 1
fi

if [[ -n "${BIN_DIR}" ]]; then
  export PATH="${BIN_DIR}:${PATH}"
fi

if ! command -v jq 1> /dev/null 2> /dev/null; then
  echo "jq command not found" >&2
  exit 1
fi

if ! command -v kubectl 1> /dev/null 2> /dev/null; then
  echo "kubectl command not found" >&2
  exit 1
fi

PATCH=$(jq -c -n --arg NS "${ARGOCD_NAMESPACE}" '[{"op": "add", "path": "/metadata/labels/argocd.argoproj.io~1managed-by", "value": $NS}]')

kubectl patch namespace "${TARGET}" --type json -p "${PATCH}"
