#!/usr/bin/env bash

INPUT=$(tee)

set +e

BIN_DIR=$(echo "${INPUT}" | grep "bin_dir" | sed -E 's/.*"bin_dir": ?"([^"]*)".*/\1/g')

export PATH="${BIN_DIR}:${PATH}"

if ! command -v kubectl 1> /dev/null 2> /dev/null; then
  echo "kubectl cli not found" >&2
  exit 1
fi

if ! command -v jq 1> /dev/null 2> /dev/null; then
  echo "jq cli not found" >&2
  exit 1
fi

export KUBECONFIG=$(echo "${INPUT}" | jq -r '.kube_config')

count=0
until kubectl get packagemanifest -A 1> /dev/null || [[ $count -gt 20 ]]; do
  count=$((count + 1))
  sleep 30
done

if [[ $count -gt 20 ]]; then
  echo "Timed out waiting for packagemanifest crd" &>2
  exit 1
fi

count=0
until [[ $(kubectl get packagemanifest -A -o json | jq -c '. | length') -gt 0 ]] || [[ $count -gt 20 ]]; do
  count=$((count + 1))
  sleep 30
done

if [[ $count -gt 20 ]]; then
  echo "Timed out waiting for packagemanifests" &>2
  exit 1
fi

PACKAGE_MANIFEST=$(kubectl get packagemanifest -A -o json | jq '[.items[] | select(.status.packageName == "openshift-gitops-operator" or .status.packageName == "argocd-operator") | {"catalogSource":.status.catalogSource,"catalogSourceNamespace":.status.catalogSourceNamespace,"packageName":.status.packageName,"defaultChannel":.status.defaultChannel}]')

OPERATOR_CONFIG=$(echo "${PACKAGE_MANIFEST}" | jq -c '.[] | select(.packageName == "openshift-gitops-operator")')
if [[ -z "${OPERATOR_CONFIG}" ]]; then
  OPERATOR_CONFIG=$(echo "${PACKAGE_MANIFEST}" | jq -c '.[] | select(.packageName == "argocd-operator")')
fi

if [[ -z "${OPERATOR_CONFIG}" ]]; then
  echo "Unable to find ArgoCD operator" &>2
  exit 1
fi

echo "${OPERATOR_CONFIG}"
