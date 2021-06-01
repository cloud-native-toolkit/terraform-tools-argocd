#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"

DEPLOYMENTS="${NAME}-repo-server,${NAME}-redis,${NAME}-application-controller,${NAME}-server"

IFS=","
for DEPLOYMENT in ${DEPLOYMENTS}; do
  count=0
  until kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" 1> /dev/null 2> /dev/null || \
        kubectl get statefulset "${DEPLOYMENT}" -n "${NAMESPACE}" 1> /dev/null 2> /dev/null;
  do
    if [[ ${count} -eq 24 ]]; then
      echo "Timed out waiting for deployment/${DEPLOYMENT} or statefulset/${DEPLOYMENT} in ${NAMESPACE} to start"
      kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" || \
        kubectl get statefulset "${DEPLOYMENT}" -n "${NAMESPACE}"
      exit 1
    else
      count=$((count + 1))
    fi

    echo "Waiting for deployment/${DEPLOYMENT} or statefulset/${DEPLOYMENT} in ${NAMESPACE} to start"
    sleep 10
  done

  if kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; then
    kubectl rollout status deployment "${DEPLOYMENT}" -n "${NAMESPACE}"
  else
    kubectl rollout status statefulset "${DEPLOYMENT}" -n "${NAMESPACE}"
  fi
done

count=0
while kubectl get pods -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' -n "${NAMESPACE}" | grep -q Pending; do
  if [[ ${count} -eq 24 ]]; then
    echo "Timed out waiting for pods in ${NAMESPACE} to start"
    kubectl get pods -n "${NAMESPACE}"
    exit 1
  else
    count=$((count + 1))
  fi

  echo "Waiting for all pods in ${NAMESPACE} to start"
  sleep 10
done
