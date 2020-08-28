#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
MODULE_DIR=$(cd "${SCRIPT_DIR}/.."; pwd -P)

NAMESPACE="$1"
NAME="$2"

kubectl patch argocd -n "${NAMESPACE}" "${NAME}" --type merge --patch "$(cat ${MODULE_DIR}/patch/solsa/argocd-cm.yaml)"
kubectl patch deployment -n "${NAMESPACE}" "${NAME}-repo-server" --patch "$(cat ${MODULE_DIR}/patch/solsa/argocd-reposerver.yaml)"

"${SCRIPT_DIR}/wait-for-deployments.sh" "${NAMESPACE}" "${NAME}"
