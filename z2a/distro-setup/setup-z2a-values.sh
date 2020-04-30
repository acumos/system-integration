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
# Name: setup-z2a-values.sh - helper script to setup z2a-specific values
#
# Prerequisites:
# - Ubuntu Xenial (16.04), Bionic (18.04), or Centos 7 VM
#

# Set up some file location env variables
GV=$Z2A_ACUMOS_BASE/global_value.yaml
KC=$Z2A_BASE/distro-setup/kind-config.yaml
KT=$Z2A_BASE/distro-setup/kind-config.tpl
ZT=$Z2A_BASE/z2a-config/z2a_value.tpl
ZV=$Z2A_BASE/z2a-config/z2a_value.yaml

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
