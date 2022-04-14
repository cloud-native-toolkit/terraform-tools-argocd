#!/usr/bin/env bash

NAMESPACE="$1"

export PATH="${BIN_DIR}:${PATH}"

count=0
until kubectl get namespace "${NAMESPACE}" 1> /dev/null 2> /dev/null || [[ ${count} -gt 20 ]]; do
  echo "Waiting for namespace: ${NAMESPACE}"
  count=$((count + 1))
  sleep 30
done

if [[ $count -gt 20 ]]; then
  echo "Timed out waiting for namespace: ${NAMESPACE}" >&2
  exit 1
fi
