#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"

set -e

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR=".tmp"
fi
mkdir -p "${TMP_DIR}"

if ! command -v jq &> /dev/null; then
  curl -Lo /tmp/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && chmod +x /tmp/bin/jq
  export PATH=$PATH:/tmp/bin
fi

LATEST_RELEASE=$(curl -Ls https://api.github.com/repos/ibm-garage-cloud/argocd-plugin-key-protect/releases/latest | jq -r '.tag_name')
curl -Lo ${TMP_DIR}/install-plugin.tar.gz "https://github.com/ibm-garage-cloud/argocd-plugin-key-protect/releases/download/${LATEST_RELEASE}/install-plugin.tar.gz"

mkdir -p "${TMP_DIR}/argocd/bin"
cd "${TMP_DIR}/argocd/bin" && tar xzf ${TMP_DIR}/install-plugin.tar.gz && cd -

${TMP_DIR}/argocd/bin/install-plugin-dependencies.sh "${NAMESPACE}"

${TMP_DIR}/argocd/bin/install-plugin.sh "${NAMESPACE}" "${NAME}"
