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
# Name: setup-nexus.sh    - helper script to install/setup Sonatype Nexus for Acumos

# Acumos Global Values Location
GV=$Z2A_ACUMOS_BASE/global_value.yaml

# Acquire Namespace and Nexus Service values for Nexus
NAMESPACE=$(yq r $GV global.namespace)
RELEASE=$(yq r $GV global.acumosNexusService)

log "Adding Sonatype Nexus repo ...."
# Add Sonatype-Nexus repo
helm repo add oteemocharts https://oteemo.github.io/charts
helm repo update

# Local override values for 3rd party Nexus chart goes here
cat <<EOF | tee $Z2A_ACUMOS_BASE/nexus_value.yaml
#TODO: See https://github.com/Oteemo/charts/tree/master/charts/sonatype-nexus for recommended values
EOF

log "Installing Nexus Helm Chart ...."
# Install the Nexus Helm Chart
# helm install $RELEASE --namespace $NAMESPACE -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/nexus_value.yaml
helm install $RELEASE --namespace $NAMESPACE -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/nexus_value.yaml stable/sonatype-nexus

# Wait for the Nexus pods to become available
wait_for_pods 180   # seconds

POD=$(kubectl get pods --namespace=$NAMESPACE | awk '/acumos-nexus/ {print $1}')
ADMIN_PW=$(kubectl exec -it $POD --namespace=$NAMESPACE -- /bin/cat /nexus-data/admin.password)

echo $ADMIN_PW > admin.password

# Docker inspect script to determine the IP of the k8s control plane
# TODO: These commands are z2a-specific ; need to wrap in a context-aware switch
CLUSTER_NAME=$(/usr/local/bin/kind get clusters)
docker inspect hobbes-1-control-plane | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress'

# Capture the Nexus Admin TCP port from Kubernetes
kubectl get svc acumos-nexus -o=json | jq '.spec.ports[] | select(.name == "admin-http").port'

# Capture the IP address of the Nexus service to pass to config-nexus.sh
# TODO: capture the IP address of the Nexus service to pass to config-nexus.sh
# kubectl describe svc acumos-nexus-service -n acumos-dev1 | awk '/IP:/ {print $2}'