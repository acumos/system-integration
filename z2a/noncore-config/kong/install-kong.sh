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
# Name: install-kong.sh    - helper script to install the Kong Service for Acumos

# Anchor the base directory for the util.sh helper
HERE=$(dirname $(readlink -f $0))
source $HERE/utils.sh
redirect_to $HERE/install.log

# Acumos Global Values Location
GV=$ACUMOS_GLOBAL_VALUE

# Acquire Namespace and Service values for Kong
NAMESPACE=$(gv_read global.namespace)
RELEASE=$(gv_read global.acumosKongRelease)
# yq w -i $ACUMOS_GLOBAL_VALUE global.acumosKongRelease $RELEASE

log "Adding Kong repo ...."
# Add Kong repo
helm repo add kong https://charts.konghq.com
helm repo update

# Local override values for Kong chart go here
cat <<EOF | tee $HERE/kong_value.yaml
ingressController:
  installCRDs: false
EOF

log "Installing Kong Helm Chart ...."
# Install the Nexus Helm Chart
helm install $RELEASE --namespace $NAMESPACE -f $GV -f $HERE/kong_value.yaml kong/kong

# Wait for the Nexus pods to become available
wait_for_pods 180   # seconds

# Acquire the IP address of the External IP for the kong service
# export PROXY_IP=$(kubectl get -o jsonpath="{.status.loadBalancer.ingress[0].ip}" service -n $NAMESPACE $RELEASE)
# echo $PROXY_IP
# HOST=$(kubectl get svc --namespace acumos-dev1 acumos-kong-proxy-acumos-kong-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# PORT=$(kubectl get svc --namespace acumos-dev1 acumos-kong-proxy-acumos-kong-proxy -o jsonpath='{.spec.ports[0].port}')
