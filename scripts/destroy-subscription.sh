#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
MODULE_DIR=$(cd "${SCRIPT_DIR}/.."; pwd -P)

NAMESPACE="$1"

kubectl delete subscription argocd-operator -n "${NAMESPACE}" --wait=true

kubectl delete deployment argocd-operator -n "${NAMESPACE}" --wait=true

exit 0
