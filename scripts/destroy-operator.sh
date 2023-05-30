#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)

NAMESPACE="$1"
NAME="$2"
CHART="$3"
SUBSCRIPTION_NAME="$4"

if [[ "${SKIP}" == "true" ]]; then
  echo "Skipping helm deploy: ${NAME} ${CHART}"
  exit 0
fi

if [[ -n "${BIN_DIR}" ]]; then
  export PATH="${BIN_DIR}:${PATH}"
fi

echo "Uninstalling operator helm chart"
"${SCRIPT_DIR}/destroy-helm.sh" "${NAMESPACE}" "${NAME}" "${CHART}"

SUBSCRIPTION=$(oc get subscription -A -o json | jq --arg NAME "${SUBSCRIPTION_NAME}" -r '.items[] | select(.spec.name == $NAME) | .metadata.name // empty')

if [[ -z "${SUBSCRIPTION}" ]]; then
  echo "Deleting CSVs"
  SEARCH="${SUBSCRIPTION_NAME}.*"

  oc get csv -n "${NAMESPACE}" -o json | jq --arg SEARCH "${SEARCH}" -c '.items[] | select(.metadata.name | test($SEARCH)) | {"name": .metadata.name, "namespace": .metadata.namespace}' | while read csv; do
    name=$(echo "$csv" | jq -r '.name')
    namespace=$(echo "$csv" | jq -r '.namespace')

    oc delete csv -n "${namespace}" "${name}" 2> /dev/null
  done

  echo "CSVs deleted"
else
  echo "Subscription still installed"
fi
