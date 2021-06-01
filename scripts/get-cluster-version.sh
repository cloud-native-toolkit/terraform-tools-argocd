#!/usr/bin/env bash

OUTPUT_FILE="$1"

OUTPUT_DIR=$(cd $(dirname "${OUTPUT_FILE}"); pwd -P)
mkdir -p "${OUTPUT_DIR}"

if ! kubectl get clusterversion; then
  echo "Getting kubernetes version"
  CLUSTER_VERSION=$(kubectl version  --short | grep -i server | sed -E "s/.*: +[vV]*(.*)/\1/g")
else
  CLUSTER_VERSION=$(oc get clusterversion | grep -E "^version" | sed -E "s/version[ \t]+([0-9.]+).*/\1/g")
fi
echo "Cluster version: ${CLUSTER_VERSION}"

echo -n "${CLUSTER_VERSION}" > "${OUTPUT_FILE}"
