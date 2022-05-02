#!/usr/bin/env bash

NAMESPACE="$1"
LABEL="$2"

export PATH="${BIN_DIR}:${PATH}"

sleep 30

kubectl get statefulset,deployment -n "${NAMESPACE}" -l "${LABEL}" -o json | jq -c '.[] | {"kind": .kind, "name": .metadata.name}' | while read resource; do
  kind=$(echo "${resource}" | jq -r '.kind')
  name=$(echo "${resource}" | jq -r '.name')

  echo "Waiting for ${kind}/${name} in ${NAMESPACE}"
  kubectl rollout status -n "${NAMESPACE}" "${kind}/${name}" --timeout=1h || exit 1
done

# do it again in case there are new ones
kubectl get statefulset,deployment -n "${NAMESPACE}" -l "${LABEL}" -o json | jq -c '.[] | {"kind": .kind, "name": .metadata.name}' | while read resource; do
  kind=$(echo "${resource}" | jq -r '.kind')
  name=$(echo "${resource}" | jq -r '.name')

  kubectl rollout status -n "${NAMESPACE}" "${kind}/${name}" --timeout=30m || exit 1
done
