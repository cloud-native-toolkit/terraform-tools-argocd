#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
MODULE_DIR=$(cd "${SCRIPT_DIR}/.."; pwd -P)

NAMESPACE="$1"

kubectl patch configmap -n "${NAMESPACE}" argocd-cm --patch "$(cat ${MODULE_DIR}/patch/solsa/argocd-cm.yaml)"
kubectl patch deployment -n "${NAMESPACE}" argocd-repo-server --patch "$(cat ${MODULE_DIR}/patch/solsa/argocd-reposerver.yaml)"
