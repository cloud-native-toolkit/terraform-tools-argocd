#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)

CURRENT_DIR=$(cd "${PWD}"; pwd -P)

NAMESPACE="$1"
NAME="$2"

set -e

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR="${CURRENT_DIR}/.tmp"
fi
mkdir -p "${TMP_DIR}"

if ! command -v jq &> /dev/null; then
  echo "Downloading jq binary"
  curl -Lo /tmp/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && chmod +x /tmp/bin/jq
  export PATH=$PATH:/tmp/bin
fi

LATEST_RELEASE=$(curl -Ls https://api.github.com/repos/ibm-garage-cloud/argocd-plugin-key-protect/releases/latest | jq -r '.tag_name')
echo "Latest release of Key Protect plugin: ${LATEST_RELEASE}"

echo "Downloading Key Protect plugin installer"
curl -Lo ${TMP_DIR}/install-plugin.tar.gz "https://github.com/ibm-garage-cloud/argocd-plugin-key-protect/releases/download/${LATEST_RELEASE}/install-plugin.tar.gz"

echo "Extracting Key Protect plugin installer"
mkdir -p "${TMP_DIR}/argocd/bin"
cd "${TMP_DIR}/argocd/bin" && tar xzvf ${TMP_DIR}/install-plugin.tar.gz && cd -

echo "Installing Key Protect plugin dependencies"
${TMP_DIR}/argocd/bin/install-plugin-dependencies.sh "${NAMESPACE}"

echo "Installing Key Protect plugin"
${TMP_DIR}/argocd/bin/install-plugin.sh "${NAMESPACE}" "${NAME}"

"${SCRIPT_DIR}/wait-for-deployments.sh" "${NAMESPACE}" "${NAME}"
