#!/usr/bin/env bash

export PATH="${BIN_DIR}:${PATH}"

if ! command -v kubectl 1> /dev/null 2> /dev/null; then
  echo "kubectl cli not found" >&2
  exit 1
fi

count=0
until kubectl get crd appprojects.argoproj.io 1> /dev/null 2> /dev/null || [[ $count -gt 20 ]]; do
  echo "Waiting for ArgoCD CRDs"
  count=$((count + 1))
  sleep 30
done

if [[ $count -gt 20 ]]; then
  echo "Timed out waiting for ArgoCD CRDs" >&2
  kubectl get crd | grep argo
  exit 1
fi

echo "ArgoCD CRDs installed..."
