#!/usr/bin/env bash

NAMESPACE="$1"

export PATH="${BIN_DIR}:${PATH}"

LABEL="app.kubernetes.io/part-of=argocd"

count=0
until [[ $(kubectl get statefulset -n "${NAMESPACE}" -l "${LABEL}" -o json | jq '.items | length') -gt 0 ]] || [[ $count -gt 20 ]]; do
  echo "Waiting for StatefulSet in ${NAMESPACE} with label ${LABEL}"
  count=$((count + 1))
  sleep 30
done

if [[ $count -gt 20 ]]; then
  echo "Timed out waiting for StatefulSet in ${NAMESPACE} with label ${LABEL}" >&2
  kubectl get statefulset -n "${NAMESPACE}" --show-labels
  exit 1
fi

name=$(kubectl get statefulset -n "${NAMESPACE}" -l "${LABEL}" -o json | jq -r '.items[0].metadata.name')

if [[ -z "${name}" ]]; then
  echo "StatefulSet name not found" >&2
  exit 1
fi

kubectl rollout status -n "${NAMESPACE}" "statefulset/${name}"
