#!/usr/bin/env bash

NAMESPACE="$1"

kubectl get statefulset -n "${NAMESPACE}" -l app.kubernetes.io/part-of=argocd -o jsonpath='{range .items[]}{.metadata.name}{"\n"}{end}' | while read name; do
  kubectl rollout status "statefulset/${name}"
done
