#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"
CHART="$3"

if [[ "${SKIP}" == "true" ]]; then
  echo "Skipping helm deploy: ${NAME} ${CHART}"
  exit 0
fi

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

if ! command -v kubectl 1> /dev/null 2> /dev/null; then
  echo "kubectl cli missing" >&2
  exit 1
fi

if [[ -n "${REPO}" ]]; then
  repo_config="--repo ${REPO}"
fi

if helm status -n "${NAMESPACE}" "${NAME}" 1> /dev/null 2> /dev/null; then
  helm delete -n "${NAMESPACE}" "${NAME}"
fi
