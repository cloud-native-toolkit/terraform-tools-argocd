#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
MODULE_DIR=$(cd "${SCRIPT_DIR}/.."; pwd -P)

NAMESPACE="$1"
NAME="$2"

kubectl delete argocds.argoproj.io "${NAME}" -n "${NAMESPACE}" --wait=true

kubectl delete deployment -l "app.kubernetes.io/part-of=argocd" -n "${NAMESPACE}" --wait=true

until kubectl get deployment -l "app.kubernetes.io/part-of=argocd" -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; do
  echo "Waiting for deployments to be deleted"
  sleep 30
done

kubectl delete serviceaccount -n "${NAMESPACE}" argocd-server --wait=true
kubectl delete serviceaccount -n "${NAMESPACE}" argocd-application-controller --wait=true
kubectl delete serviceaccount -n "${NAMESPACE}" argocd-dex-server --wait=true
kubectl delete serviceaccount -n "${NAMESPACE}" argocd-redis-ha --wait=true
kubectl delete serviceaccount -n "${NAMESPACE}" argocd-redis-ha-haproxy --wait=true

sleep 20

exit 0
