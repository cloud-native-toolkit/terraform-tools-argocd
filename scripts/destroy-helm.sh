#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"
CHART="$3"

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR="./tmp"
fi
mkdir -p "${TMP_DIR}"

if [[ -n "${BIN_DIR}" ]]; then
  export PATH="${BIN_DIR}:${PATH}"
fi

VALUES_FILE="${TMP_DIR}/${NAME}-values.yaml"

echo "${VALUES_FILE_CONTENT}" > "${VALUES_FILE}"

if ! command -v helm 1> /dev/null 2> /dev/null; then
  echo "helm cli missing" >&2
  exit 1
fi

helm delete "${NAME}" -n "${NAMESPACE}" || echo "Unable to find helm release: ${NAME}"
