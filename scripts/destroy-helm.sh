#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"
CHART="$3"

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR="./tmp"
fi
mkdir -p "${TMP_DIR}"

VALUES_FILE="${TMP_DIR}/${NAME}-values.yaml"

echo "${VALUES_FILE_CONTENT}" > "${VALUES_FILE}"

HELM=$(command -v "${BIN_DIR}/helm")

kubectl config set-context --current --namespace "${NAMESPACE}"

if [[ -n "${REPO}" ]]; then
  repo_config="--repo ${REPO}"
fi

${HELM} template "${NAME}" "${CHART}" ${repo_config} --values "${VALUES_FILE}" | kubectl delete -f -
