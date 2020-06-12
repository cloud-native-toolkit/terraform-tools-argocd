#!/usr/bin/env bash

CLUSTER_TYPE="$1"
NAMESPACE="$2"

set -e

echo "Verifying resources in $NAMESPACE namespace"

kubectl get -n "${NAMESPACE}" pods -o jsonpath='{range .items[*]}{.kind}{"/"}{.metadata.name}{": "}{.status.phase}{"\n"}{end}'
POD_STATUSES=$(kubectl get -n "${NAMESPACE}" pods -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' | grep -v "Running" | grep -v "Succeeded" | sort -u | tr '\n' ',')
if [[ -n "${POD_STATUSES}" ]]; then
  echo "  Pods have error statuses: ${POD_STATUSES}"
  exit 1
fi
