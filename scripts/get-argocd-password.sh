#!/usr/bin/env bash

NAMESPACE="$1"
OUTPUT_FILE="$2"

kubectl get secret argocd-secret -n "${NAMESPACE}" -o jsonpath='{ .data.admin\.password }' | base64 -d > "${OUTPUT_FILE}"
