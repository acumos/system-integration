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
# Name: 0a-env.sh      - end-user environment initialization script
#
# Usage: execute this script prior to running any of the Phase 2 subordinate scripts
# for installation or configuration of Acumos core and/or non-core components.
#
# Example values:
# Z2A_ACUMOS_BASE=$HOME/src/local/system-integration/helm-charts
# Z2A_ACUMOS_CORE=$HOME/src/local/system-integration/helm-charts/acumos
# Z2A_ACUMOS_DEPENDENCIES=$HOME/src/local/system-integration/helm-charts/dependencies
# Z2A_ACUMOS_NON_CORE=$HOME/src/local/system-integration/helm-charts/dependencies/k8s-noncore-chart/charts
# Z2A_BASE=$HOME/src/local/system-integration/z2a
# Z2A_K8S_CLUSTERNAME=acumos
# Z2A_K8S_NAMESPACE=acumos-dev1
#

# Create user environment
for v in $(set | grep ^Z2A_) ; do
	unset ${v%=**}
done

# Anchor Z2A_BASE value
Z2A_BASE=$(realpath $(dirname $0)/..)
# Z2A_* environment values
Z2A_ACUMOS_BASE=$(realpath $Z2A_BASE/../helm-charts)
Z2A_ACUMOS_CORE=$Z2A_ACUMOS_BASE/acumos
Z2A_ACUMOS_DEPENDENCIES=$Z2A_ACUMOS_BASE/dependencies
Z2A_ACUMOS_NON_CORE=$Z2A_ACUMOS_BASE/dependencies/k8s-noncore-chart/charts
# Create clean working copy of global_value.yaml to work with
mv $Z2A_ACUMOS_BASE/global_value.yaml $Z2A_ACUMOS_BASE/global_value.yaml.orig
egrep -v '^\s*#' $Z2A_ACUMOS_BASE/global_value.yaml.orig > $Z2A_ACUMOS_BASE/global_value.yaml
# Z2A K8S environment values
Z2A_K8S_CLUSTERNAME=$(yq r $Z2A_ACUMOS_BASE/global_value.yaml global.clusterName)
Z2A_K8S_NAMESPACE=$(yq r $Z2A_ACUMOS_BASE/global_value.yaml global.namespace)

# Source the z2a utils file
source $Z2A_BASE/z2a-utils.sh
# Save initial user environment
save_env

HERE=$(realpath $(dirname $0))
# Set up some file location env variables
GV=$Z2A_ACUMOS_BASE/global_value.yaml
KC=$HERE/kind-config.yaml
KT=$HERE/kind-config.tpl
ZT=$HERE/z2a_value.tpl
ZV=$HERE/z2a_value.yaml

Z2A_VALUE_OVERRIDE=$ZV
save_env

# Strip comments from kind template file
egrep -v '^\s*#' $ZT > $ZV

# Write out Z2A_K8S_NAMESPACE to z2a_value.yaml
yq w -i $ZV z2a.namespace $Z2A_K8S_NAMESPACE

# Associate local variable with Acumos global value
KIBANA_PORT=$(yq r $GV global.acumosKibanaPort)
KONG_PORT=$(yq r $GV global.acumosKongPort)
NEXUS_PORT=$(yq r $GV global.acumosNexusPort)
NEXUS_ADMIN_PORT=$(yq r $GV global.acumosNexusEndpointPort)

# Write z2a port value into kind cluster config
yq w -i $ZV z2a.ports.kibanaDst $KIBANA_PORT
yq w -i $ZV z2a.ports.kongDst $KONG_PORT
yq w -i $ZV z2a.ports.nexusDst $NEXUS_PORT
yq w -i $ZV z2a.ports.nexusAdminDst $NEXUS_ADMIN_PORT

# Associate local variables with Acumos global value file
KIBANA_SVC=$(yq r $GV global.acumosKibanaService)
KONG_SVC=$(yq r $GV global.acumosKongService)
NEXUS_SVC=$(yq r $GV global.acumosNexusService)
NEXUS_ADMIN_SVC=$(yq r $GV global.acumosNexusService)

# Write z2a service names into kind cluster config
yq w -i $ZV z2a.ports.kibanaSvc $KIBANA_SVC
yq w -i $ZV z2a.ports.kongSvc $KONG_SVC
yq w -i $ZV z2a.ports.nexusSvc $NEXUS_SVC
yq w -i $ZV z2a.ports.nexusAdminSvc $NEXUS_ADMIN_SVC

KIBANA_PORT=$(yq r $ZV z2a.ports.kibanaSrc)
KONG_PORT=$(yq r $ZV z2a.ports.kongSrc)
NEXUS_PORT=$(yq r $ZV z2a.ports.nexusSrc)
NEXUS_ADMIN_PORT=$(yq r $ZV z2a.ports.nexusAdminSrc)

# Static Values - go here
K8S_DASHBOARD_PORT=9090
yq w -i $ZV z2a.ports.k8sDashSrc $K8S_DASHBOARD_PORT
yq w -i $ZV z2a.ports.k8sDashDst $K8S_DASHBOARD_PORT

# Strip comments from kind config file
egrep -v '^\s*#' $KT > $KC

# Create a key from kind-config.yaml file
KEY=$(yq r -p p $KC 'nodes.(kubeadmConfigPatches==*)')

# Remove the extraPortMappings block using KEY
yq d -i $KC $KEY.extraPortMappings

# Loop thru placeholders and build YAML block for kind config
i=0
for PORT in $KIBANA_PORT $NEXUS_PORT $K8S_DASHBOARD_PORT ; do
  yq w -i $KC $KEY.extraPortMappings[$i].containerPort $PORT
  yq w -i $KC $KEY.extraPortMappings[$i].hostPort $PORT
  yq w -i $KC $KEY.extraPortMappings[$i].listenAddress 0.0.0.0
  yq w -i $KC $KEY.extraPortMappings[$i].protocol TCP
  ((i=i+1))
done

redirect_to /dev/null
log "Phase 0a-env (end-user environment) creation ...."
