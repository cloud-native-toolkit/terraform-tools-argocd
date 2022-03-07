#!/usr/bin/env bash

INPUT=$(tee)

export KUBECONFIG=$(echo "${INPUT}" | grep "kube_config" | sed -E 's/.*"kube_config": ?"([^"]*)".*/\1/g')
BIN_DIR=$(echo "${INPUT}" | grep "bin_dir" | sed -E 's/.*"bin_dir": ?"([^"]*)".*/\1/g')

if ! ${BIN_DIR}/kubectl get clusterversion 1> /dev/null 2> /dev/null; then
  CLUSTER_VERSION=$(${BIN_DIR}/kubectl version  --short | grep -i server | sed -E "s/.*: +[vV]*(.*)/\1/g")
else
  CLUSTER_VERSION=$(${BIN_DIR}/oc get clusterversion | grep -E "^version" | sed -E "s/version[ \t]+([0-9.]+).*/\1/g")
fi

echo "{\"clusterVersion\": \"${CLUSTER_VERSION}\"}"
