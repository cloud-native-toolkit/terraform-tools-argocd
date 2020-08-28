#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)

CLUSTER_TYPE="$1"
NAMESPACE="$2"

export KUBECONFIG="${SCRIPT_DIR}/.kube/config"

echo "Verifying resources in $NAMESPACE namespace"

if kubectl get configmap -n "${NAMESPACE}" argocd-cm -o jsonpath='{.data.configManagementPlugins}' | grep "name: solsa"; then
  echo "Solsa plugin found"
else
  echo "Solsa plugin not installed"
  exit 1
fi

# TODO: For now we will exclude Pending status from failed statuses. Need to revisit
PODS=$(kubectl get -n "${NAMESPACE}" pods -o jsonpath='{range .items[*]}{.status.phase}{": "}{.kind}{"/"}{.metadata.name}{"\n"}{end}' | grep -v "Running" | grep -v "Succeeded" | grep -v "Pending")
POD_STATUSES=$(echo "${PODS}" | sed -E "s/(.*):.*/\1/g")
if [[ -n "${POD_STATUSES}" ]]; then
  echo "  Pods have non-success statuses: ${PODS}"
  exit 1
fi

set -e

if [[ "${CLUSTER_TYPE}" == "kubernetes" ]] || [[ "${CLUSTER_TYPE}" =~ iks.* ]]; then
  ENDPOINTS=$(kubectl get ingress -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{range .spec.rules[*]}{"https://"}{.host}{"\n"}{end}{end}')
else
  ENDPOINTS=$(kubectl get route -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{"https://"}{.spec.host}{"\n"}{end}')
fi

echo "Validating endpoints:"
echo "${ENDPOINTS}"

echo "${ENDPOINTS}" | while read endpoint; do
  if [[ -n "${endpoint}" ]]; then
    ${SCRIPT_DIR}/waitForEndpoint.sh "${endpoint}" 10 10
  fi
done

CONFIG_URLS=$(kubectl get configmap -n "${NAMESPACE}" -l grouping=garage-cloud-native-toolkit -l app.kubernetes.io/component=tools -o json | jq '.items[].data | to_entries | select(.[].key | endswith("_URL")) | .[].value' | sed "s/\"//g")

echo "Validating config urls:"
echo "${CONFIG_URLS}"

echo "${CONFIG_URLS}" | while read url; do
  if [[ -n "${url}" ]]; then
    ${SCRIPT_DIR}/waitForEndpoint.sh "${url}" 10 10
  fi
done

exit 0
