#!/usr/bin/env bash

URL="$1"
WAIT_TIME=$2
WAIT_COUNT=$3
NAMESPACE="$4"

if [[ -z "${WAIT_TIME}" ]]; then
  WAIT_TIME=15
fi

if [[ -z "${WAIT_COUNT}" ]]; then
  WAIT_COUNT=40
fi

count=0

sleep 20

until curl -X GET -Iqs --insecure "${URL}" | grep -q -E "403|200" || \
  [[ $count -eq ${WAIT_COUNT} ]]
do
    echo ">>> waiting for ${URL} to be available"

    sleep ${WAIT_TIME}
    count=$((count + 1))
done

if [[ $count -eq ${WAIT_COUNT} ]]; then
  echo ">>> Retry count exceeded. ${URL} not available"
  if [[ -n "${NAMESPACE}" ]]; then
    kubectl get deployment,pod,service -n "${NAMESPACE}" -o yaml
  fi
  exit 1
else
  echo ">>> ${URL} is available"
fi
