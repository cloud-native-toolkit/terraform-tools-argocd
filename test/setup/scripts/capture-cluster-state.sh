#!/usr/bin/env bash

PLATFORM="$1"
NAMESPACE="$2"
OUTFILE="$3"

OUTFILE_DIR=$(dirname "${OUTFILE}")
mkdir -p "${OUTFILE_DIR}"

resources="deployment,statefulset,service,ingress,configmap,secret"
if [[ "$PLATFORM" == "ocp3" ]] || [[ "$PLATFORM" == "ocp4" ]]; then
  resources="${resources},route"

  if [[ "$PLATFORM" == "ocp4" ]]; then
    resources="${resources},consolelink"
  fi
fi

echo "Checking on namespace - ${NAMESPACE}"

if kubectl get namespace "${NAMESPACE}" 1> /dev/null 2> /dev/null; then
  echo "Listing resources in namespace - ${resources}"

  kubectl get -n "${NAMESPACE}" "${resources}" -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.kind}{"/"}{.metadata.name}{"\n"}{end}' | \
    tr '[:upper:]' '[:lower:]' > "${OUTFILE}"
else
  echo "Namespace does not exist - ${NAMESPACE}"
  touch "${OUTFILE}"
fi

if kubectl get subscription --all-namespaces 1> /dev/null 2> /dev/null; then
  kubectl get --all-namespaces subscription -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.kind}{"/"}{.metadata.name}{"\n"}{end}' 2> /dev/null | \
    tr '[:upper:]' '[:lower:]' >> "${OUTFILE}"
fi

cat "${OUTFILE}"
