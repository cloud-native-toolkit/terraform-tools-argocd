#! /bin/bash

while read -r resource; do
    terraform destroy -target="$resource" -auto-approve
done < <(terraform state list | grep -vE "^data\." | grep -vE "module.dev_cluster")