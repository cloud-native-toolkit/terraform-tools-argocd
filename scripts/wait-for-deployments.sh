#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"

DEPLOYMENTS="${NAME}-repo-server,${NAME}-redis,${NAME}-dex-server,${NAME}-application-controller,${NAME}-server"

IFS=","
for DEPLOYMENT in ${DEPLOYMENTS}; do
  count=0
  until kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; do
    if [[ ${count} -eq 24 ]]; then
      echo "Timed out waiting for deployment/${DEPLOYMENT} in ${NAMESPACE} to start"
      exit 1
    else
      count=$((count + 1))
    fi

    echo "Waiting for deployment/${DEPLOYMENT} in ${NAMESPACE} to start"
    sleep 10
  done

  kubectl rollout status deployment "${DEPLOYMENT}" -n "${NAMESPACE}"
done
