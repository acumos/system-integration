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
# Name: setup-port-mappings.sh - helper script to map Acumos ports to kind ports
#
# Prerequisites:
# - Ubuntu Xenial (16.04), Bionic (18.04), or Centos 7 VM
#

GV=$Z2A_ACUMOS_BASE/global_value.yaml
KC=$Z2A_BASE/distro-setup/kind-config.yaml
ZV=$Z2A_BASE/z2a-config/z2a_values.yaml

KIBANA_PORT=$(yq r $GV global.acumosKibanaPort)
KONG_PORT=$(yq r $GV global.acumosKongPort)
NEXUS_PORT=$(yq r $GV global.acumosNexusPort)
NEXUS_ADMIN_PORT=$(yq r $GV global.acumosNexusEndpointPort)

yq w -i $ZV z2a.ports.kibanaDst $KIBANA_PORT
yq w -i $ZV z2a.ports.kongDst $KONG_PORT
yq w -i $ZV z2a.ports.nexusDst $NEXUS_PORT
yq w -i $ZV z2a.ports.nexusAdminDst $NEXUS_ADMIN_PORT

