#!/usr/bin/env bash

NAMESPACE="$1"
OUTPUT_FILE="$2"

if [[ -z "${OUTPUT_FILE}" ]]; then
  echo "OUTPUT_FILE is required"
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_FILE}")"

count=0
until kubectl get secret argocd-secret -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; do
  if [[ $count -eq 10 ]]; then
    echo "Timed out waiting for secret ${NAMESPACE}/argocd-secret"
    exit 1
  fi

  count=$((count + 1))
  echo "Waiting for secret ${NAMESPACE}/argocd-secret"
  kubectl get all -n "${NAMESPACE}"
  kubectl get secret -n "${NAMESPACE}"
  sleep 30
done

NEW_PASSWORD=$(LC_ALL=C tr -dc '!-~' </dev/urandom | head -c 13; echo)
BCRYPT_PASSWORD=$(htpasswd -bnBC 10 "" "${NEW_PASSWORD}" | sed -E '/^:/s/:(.*)$/\1/p;d' | sed 's/$2y/$2a/')
kubectl patch secret argocd-secret -n "${NAMESPACE}" \
  -p "{\"stringData\": {
    \"admin.password\": \"${BCRYPT_PASSWORD}\",
    \"admin.passwordMtime\": \"$(date +%FT%T%Z)\"
  }}"

kubectl patch secret argocd-cluster-cluster -n "${NAMESPACE}" \
  -p "{\"stringData\": {
    \"admin.password\": \"${NEW_PASSWORD}\"
  }}"

kubectl delete pod -n "${NAMESPACE}" -l app.kubernetes.io/name=argocd-cluster-application-controller
kubectl delete pod -n "${NAMESPACE}" -l app.kubernetes.io/name=argocd-cluster-redis
kubectl delete pod -n "${NAMESPACE}" -l app.kubernetes.io/name=argocd-cluster-repo-server
kubectl delete pod -n "${NAMESPACE}" -l app.kubernetes.io/name=argocd-cluster-server
kubectl delete pod -n "${NAMESPACE}" -l app.kubernetes.io/name=cluster

echo -n "${NEW_PASSWORD}" > "${OUTPUT_FILE}"
