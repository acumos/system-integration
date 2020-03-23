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

# Default values for Acoumos NiFi
# Edit these values for custom values
export RELEASE=mlwb-nifi

# Add NiFi repo to Helm
log "Adding NiFi repo ...."
helm repo add cetic https://cetic.github.io/helm-charts
helm repo update

# Simple k/v map to set NiFi configuration values
cat <<EOF >$Z2A_ACUMOS_BASE/nifi_config.yaml
EOF

log "Installing NiFi Helm Chart ...."
helm install -name $RELEASE --namespace $NAMESPACE -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml -f $Z2A_ACUMOS_BASE/nifi_config.yaml cetic/nifi

log "NiFi Cluster setup information ...."
log "Cluster endpoint IP address will be available at:"
log "$(kubectl get svc $RELEASE -n $NAMESPACE)"
log "$(kubectl get svc nifi -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[*].ip}')"

log "NiFi installation complete."
log "$(Note:  DNS and/or /etc/hosts will need to be updated with the NiFi cluster information.)"