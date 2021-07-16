#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"
CHART="$3"

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR="./tmp"
fi
mkdir -p "${TMP_DIR}"

mkdir -p ./bin
BIN_DIR=$(cd ./bin; pwd -P)

VALUES_FILE="${TMP_DIR}/${NAME}-values.yaml"

echo "${VALUES_FILE_CONTENT}" > "${VALUES_FILE}"

HELM=$(command -v helm || command -v "${BIN_DIR}/helm")

if [[ -z "${HELM}" ]]; then
  curl -sLo helmx.tar.gz https://get.helm.sh/helm-v3.6.1-linux-amd64.tar.gz

  HELM=$(command -v helm || command -v "${BIN_DIR}/helm")

  if [[ -z "${HELM}" ]]; then
    mkdir helm.tmp && cd helm.tmp && tar xzf ../helmx.tar.gz

    HELM=$(command -v helm || command -v "${BIN_DIR}/helm")

    if [[ -z "${HELM}" ]]; then
      cp ./linux-amd64/helm "${BIN_DIR}/helm"

      HELM="${BIN_DIR}/helm"
    fi

    cd .. && rm -rf helm.tmp && rm helmx.tar.gz
  fi
fi

kubectl config set-context --current --namespace "${NAMESPACE}"

if [[ -n "${REPO}" ]]; then
  repo_config="--repo ${REPO}"
fi

${HELM} template "${NAME}" "${CHART}" ${repo_config} --values "${VALUES_FILE}" | kubectl apply --validate=false -f -
