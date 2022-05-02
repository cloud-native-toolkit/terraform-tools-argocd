#!/usr/bin/env bash

INPUT=$(tee)

export KUBECONFIG=$(echo "${INPUT}" | grep "kube_config" | sed -E 's/.*"kube_config": ?"([^"]*)".*/\1/g')
NAMESPACE=$(echo "${INPUT}" | grep "namespace" | sed -E 's/.*"namespace": ?"([^"]*)".*/\1/g')
BIN_DIR=$(echo "${INPUT}" | grep "bin_dir" | sed -E 's/.*"bin_dir": ?"([^"]*)".*/\1/g')
CREATED_BY=$(echo "${INPUT}" | grep "created_by" | sed -E 's/.*"created_by": ?"([^"]*)".*/\1/g')

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

## check for Subscription
SUBSCRIPTION_NAME="openshift-gitops-operator"
SUBSCRIPTION=$(oc get subscription -A -o json | jq --arg NAME "${SUBSCRIPTION_NAME}" -r '.items[] | select(.spec.name == $NAME) | .metadata.name // empty')
SUBSCRIPTION_NAMESPACE=$(oc get subscription -A -o json | jq --arg NAME "${SUBSCRIPTION_NAME}" -r '.items[] | select(.spec.name == $NAME) | .metadata.namespace // empty')
SUBSCRIPTION_CREATED_BY=$(oc get subscription -A -o json | jq --arg NAME "${SUBSCRIPTION_NAME}" -r '.items[] | select(.spec.name == $NAME) | .metadata.labels["created-by"] // empty')

## check for CSV
CSV_NAME="openshift-gitops-operator"
CSV=$(oc get csv -n "${NAMESPACE}" -o json | jq -r '.items[] | .metadata.name // empty' | grep "${CSV_NAME}")

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
  echo "The OpenShift GitOps CSV is deployed but there is no subscription" >&2
  exit 1
else
  echo '{"exists": "false"}'
  exit 0
fi
