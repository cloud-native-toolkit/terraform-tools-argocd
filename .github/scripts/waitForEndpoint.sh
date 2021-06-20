#!/usr/bin/env bash

URL="$1"
WAIT_TIME=$2
WAIT_COUNT=$3

if [[ -z "${WAIT_TIME}" ]]; then
  WAIT_TIME=15
fi

if [[ -z "${WAIT_COUNT}" ]]; then
  WAIT_COUNT=20
fi

count=0

sleep 20

until [[ $(curl -X GET -Iq --insecure "${URL}" | grep -E "403|200") ]] || \
  [[ $count -eq ${WAIT_COUNT} ]]
do
    echo ">>> waiting for ${URL} to be available"
    sleep ${WAIT_TIME}
    count=$((count + 1))
done

if [[ $count -eq ${WAIT_COUNT} ]]; then
  echo ">>> Retry count exceeded. ${URL} not available"
  exit 1
else
  echo ">>> ${URL} is available"
fi
