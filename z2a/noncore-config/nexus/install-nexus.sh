#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2020 AT&T Intellectual Property & Tech Mahindra.
# All rights reserved.
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
# Name: install-nexus.sh    - helper script to install Sonatype Nexus for Acumos

# Anchor the base directory for the util.sh helper
HERE=$(dirname $(readlink -f $0))
source $HERE/utils.sh
redirect_to $HERE/install.log

# Acumos Global Values Location
GV=$ACUMOS_GLOBAL_VALUE

# Acquire Namespace and Nexus Service values for Nexus
NAMESPACE=$(gv_read global.namespace)
RELEASE=$(gv_read global.acumosNexusRelease)

log "Adding Sonatype Nexus repo ...."
# Add Sonatype-Nexus repo
helm repo add oteemocharts https://oteemo.github.io/charts
helm repo update

#TODO: See https://github.com/Oteemo/charts/tree/master/charts/sonatype-nexus for recommended values
# Local override values for 3rd party Nexus chart goes here
cat <<EOF | tee $HERE/nexus_value.yaml
nexusProxy:
  enabled: false
service:
  enabled: true
  name: $RELEASE
  ports:
  - name: nexus-service
    targetPort: 8081
    port: 8081
EOF

log "Installing Nexus Helm Chart ...."
# Install the Nexus Helm Chart
# helm install $RELEASE --namespace $NAMESPACE -f $GV -f $HERE/nexus_value.yaml stable/sonatype-nexus
helm install $RELEASE --namespace $NAMESPACE -f $GV -f $HERE/nexus_value.yaml oteemocharts/sonatype-nexus

log "Waiting .... (up to 15 minutes) for pod ready status ...."
# Wait for the Nexus pods to become available
wait_for_pod_ready 900 $RELEASE   # seconds
kubectl get pods -o json
