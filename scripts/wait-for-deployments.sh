#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"

DEPLOYMENTS="${NAME}-server,${NAME}-repo-server,${NAME}-redis,${NAME}-dex-server,${NAME}-application-controller"

IFS=","
for DEPLOYMENT in ${DEPLOYMENTS}; do
  count=0
  until kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; do
    if [[ ${count} -eq 12 ]]; then
      echo "Timed out waiting for deployment/${DEPLOYMENT} to start"
      exit 1
    else
      count=$((count + 1))
    fi

    echo "Waiting for deployment/${DEPLOYMENT} to start"
    sleep 10
  done

  kubectl rollout status deployment "${DEPLOYMENT}" -n "${NAMESPACE}"
done
