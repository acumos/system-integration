#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2019 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
# ===================================================================================
# This Acumos software file is distributed by AT&T and Tech Mahindra
# under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# This file is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ===============LICENSE_END=========================================================
#
# Name: install-nifi.sh - installation script for NiFi dependency for MLWB

# HERE
HERE=$(realpath $(dirname $0))

# Default values for Acumos NiFi
# Edit these values for custom values
RELEASE=mlwb-nifi
# NAMESPACE=$(yq r $ACUMOS_GLOBAL_VALUE global.namespace)
MLWB_NAMESPACE=$(yq r $MLWB_GLOBAL_VALUE mlwb.namespace)

# Add NiFi repo to Helm
echo "Adding NiFi repo ...."
helm repo add cetic https://cetic.github.io/helm-charts
helm repo update

# k/v map to set NiFi configuration values
# TODO: research cetic/nifi Helm chart and populate the local override values below
cat <<EOF | tee $HERE/nifi_value.yaml
properties:
  webProxyHost:
EOF

echo "Installing NiFi Helm Chart ...."
helm install $RELEASE --namespace $MLWB_NAMESPACE -f $ACUMOS_GLOBAL_VALUE \
  -f $ACUMOS_BASE/mlwb_value.yaml -f $HERE/nifi_value.yaml cetic/nifi

# Loop for NiFi to become available
kubectl wait pods --for=condition=Ready --all --namespace=$MLWB_NAMESPACE --timeout=900s
for i in $(seq 1 20) ; do
  sleep 10
  # TODO: craft a query to determine the status of NiFi
  # kubectl exec --namespace $NAMESPACE $RELEASE
  break
  if [ $i -eq 20 ] ; then echo "\nTimeout waiting for Nifi to become available ...." ; exit ; fi
done
echo "\n"

echo "NiFi Cluster setup information ...."
echo "$(kubectl get svc $RELEASE -n $MLWB_NAMESPACE)"
echo "Cluster endpoint IP address will be available at:"
echo "$(kubectl get svc $RELEASE -n $MLWB_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[*].ip}')"

echo "NiFi installation complete."
echo "Note:  DNS and/or /etc/hosts will need to be updated with the NiFi cluster information."
