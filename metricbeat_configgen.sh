#!/bin/bash
shopt -s expand_aliases

set -euo pipefail
NAMESPACE="elastic-system"
MB_VERSION="7.16"
MB_MF="${1-metricbeat-kubernetes.yaml}"
SEC_KEY_REF="elasticsearch-sample-es-elastic-user"
echo "Printing to $MB_MF"
rm -f metricbeat*.yaml.* $MB_MF
wget https://raw.githubusercontent.com/elastic/beats/$MB_VERSION/deploy/kubernetes/metricbeat-kubernetes.yaml


if [ ! $(which yq) ]; then
    echo "please install yq"
    exit 1
fi

#yq eval 'select(di != 4) .metadata.namespace = "$NAMESPACE"' -i "$MB_MF"
#yq eval 'select(di == 2) | select(.spec.template.spec.containers.name == "metricbeat") .env[3].secretKeyRef = [{\"name\":"$SEC_KEY_REF","key":"elastic"}]' -P -i "$MB_MF"
yq eval 'select(di == 2) | .spec.template.spec.containers.[]| select(.name == "metricbeat").env[3].secretKeyRef=[{\"name\":"$SEC_KEY_REF","key":"elastic"}]' -P -i "$MB_MF"
