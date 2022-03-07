#!/usr/bin/env bash

NAMESPACE="$1"

KUBECTL="${BIN_DIR}/kubectl"

${KUBECTL} get statefulset -n "${NAMESPACE}" -l app.kubernetes.io/part-of=argocd -o jsonpath='{range .items[]}{.metadata.name}{"\n"}{end}' | while read name; do
  ${KUBECTL} rollout status "statefulset/${name}"
done
