#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
MODULE_DIR=$(cd "${SCRIPT_DIR}/.."; pwd -P)

NAMESPACE="$1"

kubectl delete subscription argocd-operator -n "${NAMESPACE}" --wait=true
kubectl delete subscription openshift-gitops-operator -n openshift-operators --wait=true

# Ideally, deleting the subscription would clean the rest of this up...
kubectl delete deployment argocd-operator -n "${NAMESPACE}" --wait=true
kubectl delete serviceaccount -n "${NAMESPACE}" argocd-operator --wait=true
kubectl delete configmap -n "${NAMESPACE}" argocd-operator-lock --wait=true

sleep 20

exit 0
