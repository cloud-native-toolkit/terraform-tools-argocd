#!/usr/bin/env bash

INPUT=$(tee)

BIN_DIR=$(echo "${INPUT}" | grep "bin_dir" | sed -E 's/.*"bin_dir": ?"([^"]*)".*/\1/g')

if [[ -n "${BIN_DIR}" ]]; then
  export PATH="${BIN_DIR}:${PATH}"
fi

if ! command -v oc 1> /dev/null 2> /dev/null; then
  echo "oc cli not found" >&2
  exit 1
fi

if ! command -v jq 1> /dev/null 2> /dev/null; then
  echo "jq cli not found" >&2
  exit 1
fi

export KUBECONFIG=$(echo "${INPUT}" | jq -r '.kube_config')
NAMESPACE=$(echo "${INPUT}" | jq -r '.namespace')
SUBSCRIPTION_NAME=$(echo "${INPUT}" | jq -r '.name')
CREATED_BY=$(echo "${INPUT}" | jq -r '.created_by')


## check for Subscription
SUBSCRIPTION_DATA=$(oc get subscription -A -o json | jq --arg NAME "${SUBSCRIPTION_NAME}" -c '.items[] | select(.spec.name == $NAME)')

SUBSCRIPTION=$(echo "${SUBSCRIPTION_DATA}" | jq -r '.metadata.name // empty')
SUBSCRIPTION_NAMESPACE=$(echo "${SUBSCRIPTION_DATA}" | jq -r '.metadata.namespace // empty')
SUBSCRIPTION_CREATED_BY=$(echo "${SUBSCRIPTION_DATA}" | jq -r '.metadata.labels["created-by"] // empty')
CURRENT_CSV=$(echo "${SUBSCRIPTION_DATA}" | jq -r '.status.currentCSV // empty')

## check for CSV
CSV=$(oc get csv -n "${SUBSCRIPTION_NAMESPACE}" "${CURRENT_CSV}" -o json | jq -r '.metadata.name // empty')

## check for CRD
CRDS=$(oc get crd -o json | jq -r '.items[] | .metadata.name | select(. | test("argocds")) | .')

## check for operator deployment
DEPLOYMENT_LABEL="olm.owner=${CSV}"
if [[ -n "${CSV}" ]]; then
  DEPLOYMENT=$(oc get deployment -n "${NAMESPACE}" -l "${DEPLOYMENT_LABEL}" -o json | jq -r '.items[] | .metadata.name')
fi

## if subscription exists but CSV or CRDs not present or deployment not found then throw error
if [[ -n "${SUBSCRIPTION}" ]]; then
  if [[ -z "${CSV}" ]]; then
    echo "${CSV_NAME} not found in ${NAMESPACE} namespace" >&2
    exit 1
  elif [[ -z "${CRDS}" ]]; then
    echo "ArgoCD crds not found" >&2
    exit 1
  elif [[ -z "${DEPLOYMENT}" ]]; then
    echo "ArgoCD deployment with label ${DEPLOYMENT_LABEL} not found" >&2
    exit 1
  fi

  CONDITIONS=$(oc get subscription -n "${SUBSCRIPTION_NAMESPACE}" "${SUBSCRIPTION}" -o json | \
    jq -c '.status.conditions[] | select(.status == "True") | .message // empty')

  if [[ -n "${CONDITIONS}" ]]; then
    echo "An OpenShift GitOps operator subscription already exists and it is not healthy" >&2
    exit 1
  fi

  if [[ "${SUBSCRIPTION_CREATED_BY}" == "${CREATED_BY}" ]]; then
    ## This will happen when terraform plan is run after the module has already been applied (i.e. destroy or apply additional content)
    ## We want to preserve the state so it doesn't trigger the content to be re-applied or for destroy to be skipped
    echo '{"exists": "false"}'
    exit 0
  else
    ## if subscription exists and everything is healthy
    echo '{"exists": "true"}'
    exit 0
  fi
elif [[ -n "${CSV}" ]]; then
  echo "The ArgoCD CSV is deployed but there is no subscription" >&2
  exit 1
else
  echo '{"exists": "false"}'
  exit 0
fi
