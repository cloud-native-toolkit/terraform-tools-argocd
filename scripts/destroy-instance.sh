#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
MODULE_DIR=$(cd "${SCRIPT_DIR}/.."; pwd -P)

NAMESPACE="$1"
NAME="$1"

kubectl delete argocds.argoproj.io "${NAME}" -n "${NAMESPACE}"
