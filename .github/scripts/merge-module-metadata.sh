#!/usr/bin/env bash

UPDATE_DIR="$1"

if [[ -f "index.yaml" ]]; then
  yq r index.yaml versions | yq p - versions > tmp.yaml
  yq m -i -a "${UPDATE_DIR}/module.yaml" tmp.yaml
  rm tmp.yaml
fi

cp "${UPDATE_DIR}/module.yaml" "${UPDATE_DIR}/index.yaml"
rm "${UPDATE_DIR}/module.yaml"
