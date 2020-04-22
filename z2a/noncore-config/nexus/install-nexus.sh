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
RELEASE=$(gv_read global.acumosNexusService)

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

# Wait for the Nexus pods to become available
wait_for_pods 180   # seconds
# TODO:  add wait_for_pod_ready function to ensure Pod is in a ready state
sleep 300 # seconds

# From deprecated stable/sonatype-nexus chart
# POD=$(kubectl get pods --namespace=$NAMESPACE | awk '/acumos-nexus/ {print $1}')
# ADMIN_PW=$(kubectl exec -it $POD --namespace=$NAMESPACE -- /bin/cat /nexus-data/admin.password)

# Default setting
ADMIN_PW=admin123
echo $ADMIN_PW > admin.password

# Docker inspect script to determine the IP of the k8s control plane
# TODO: These commands are kind and z2a-specific ; need to wrap in a context-aware switch
# CLUSTER_NAME=$(/usr/local/bin/kind get clusters)
# docker inspect hobbes-1-control-plane | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress'

# Capture the Nexus Admin TCP port from Kubernetes
# kubectl get svc acumos-nexus -o=json | jq '.spec.ports[] | select(.name == "admin-http").port'

# Capture the IP address of the Nexus service to pass to config-nexus.sh
# TODO: capture the IP address of the Nexus service to pass to config-nexus.sh
# kubectl describe svc acumos-nexus -n $NAMESPACE | awk '/IP:/ {print $2}'