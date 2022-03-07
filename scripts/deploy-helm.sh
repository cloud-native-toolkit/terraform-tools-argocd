#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"
CHART="$3"

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR="./tmp"
fi
mkdir -p "${TMP_DIR}"

if [[ -z "${BIN_DIR}" ]]; then
  BIN_DIR="/usr/local/bin"
fi

VALUES_FILE="${TMP_DIR}/${NAME}-values.yaml"

echo "${VALUES_FILE_CONTENT}" > "${VALUES_FILE}"

HELM=$(command -v "${BIN_DIR}/helm" || command -v helm)
if [[ -z "${HELM}" ]]; then
  echo "helm cli missing"
  exit 1
fi

KUBECTL=$(command -v "${BIN_DIR}/kubectl" || command -v kubectl)
if [[ -z "${KUBECTL}" ]]; then
  echo "kubectl cli missing"
  exit 1
fi

${KUBECTL} config set-context --current --namespace "${NAMESPACE}"

if [[ -n "${REPO}" ]]; then
  repo_config="--repo ${REPO}"
fi

${HELM} template "${NAME}" "${CHART}" ${repo_config} --values "${VALUES_FILE}" | ${KUBECTL} apply --validate=false -f -
