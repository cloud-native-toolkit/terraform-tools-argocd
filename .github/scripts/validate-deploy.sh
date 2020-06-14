#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)

CLUSTER_TYPE="$1"
NAMESPACE="$2"

echo "Verifying resources in $NAMESPACE namespace"

# TODO: For now we will exclude Pending status from failed statuses. Need to revisit
PODS=$(kubectl get -n "${NAMESPACE}" pods -o jsonpath='{range .items[*]}{.status.phase}{": "}{.kind}{"/"}{.metadata.name}{"\n"}{end}' | grep -v "Running" | grep -v "Succeeded" | grep -v "Pending")
POD_STATUSES=$(echo "${PODS}" | sed -E "s/(.*):.*/\1/g")
if [[ -n "${POD_STATUSES}" ]]; then
  echo "  Pods have non-success statuses: ${PODS}"
  exit 1
fi

set -e

if [[ "${CLUSTER_TYPE}" == "kubernetes" ]] || [[ "${CLUSTER_TYPE}" == "iks" ]]; then
  ENDPOINTS=$(kubectl get ingress -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{range .spec.rules[*]}{"https://"}{.host}{"\n"}{end}{end}')
else
  ENDPOINTS=$(kubectl get route -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{"https://"}{.spec.host}{"\n"}{end}')
fi

echo "Validating endpoints:\n${ENDPOINTS}"

echo "${ENDPOINTS}" | while read endpoint; do
  ${SCRIPT_DIR}/waitForEndpoint.sh "${endpoint}" 10 10
done

CONFIG_URLS=$(kubectl get configmap -n "${NAMESPPACE}" -l grouping=garage-cloud-native-toolkit -o json | jq '.items[].data | to_entries | select(.[].key | endswith("_URL")) | .[].value')

echo "${CONFIG_URLS}" | while read url; do
  ${SCRIPT_DIR}/waitForEndpoint.sh "${url}" 10 10
done

exit 0
