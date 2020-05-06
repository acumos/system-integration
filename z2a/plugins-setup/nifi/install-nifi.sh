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
# Name: installnifi.sh - installation script for NiFi dependency for MLWB

# Default values for Acumos NiFi
# Edit these values for custom values
export RELEASE=mlwb-nifi

# Add NiFi repo to Helm
log "Adding NiFi repo ...."
helm repo add cetic https://cetic.github.io/helm-charts
helm repo update

# k/v map to set NiFi configuration values
cat <<EOF | tee $Z2A_ACUMOS_BASE/nifi_value.yaml
EOF

log "Installing NiFi Helm Chart ...."
helm install $RELEASE --namespace $NAMESPACE -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml -f $Z2A_ACUMOS_BASE/nifi_value.yaml cetic/nifi

# Loop for NiFi to become available
for i in $(seq 1 20) ; do
  sleep 10
  logc .
  TODO: craft a query to determine the status of NiFi
  # kubectl exec --namespace $NAMESPACE $RELEASE
  if [ $i -eq 20 ] ; then log "\nTimeout waiting for Nifi to become available ...." ; exit ; fi
done
log "\n"

log "NiFi Cluster setup information ...."
log "$(kubectl get svc $RELEASE -n $NAMESPACE)"
log "Cluster endpoint IP address will be available at:"
log "$(kubectl get svc $RELEASE -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[*].ip}')"

log "NiFi installation complete."
log "Note:  DNS and/or /etc/hosts will need to be updated with the NiFi cluster information."
