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
#
# Notes:
#
# Please note that at this time there are two options for installing Kong.
# Option 1: uses the Helm Chart from HelmHQ
# Option 2: uses the Helm Chart from Bitnami
#


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

log "Adding Bitnami repo ...."
# Add Bitnami repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Comment out Bitnami above and uncomment below for alternative KongHQ chart
# log "Adding KongHQ repo ...."
# helm repo add kong https://charts.konghq.com
# helm repo update

# Local override values for KongHQ chart & PostgreSQL chart go here
# Note: KongHQ Chart pulls in the Bitnami PostgreSQL chart when enabled
POSTGRES_DATABASE=$(gv_read global.acumosKongPostgresDB)
POSTGRES_PASSWORD=$(gv_read global.acumosKongPostgresPassword)
POSTGRES_PORT=$(gv_read acumosKongPostgresPort)
cat <<EOF | tee $HERE/kong_value.yaml
ingressController:
  installCRDs: false
EOF

log "Installing Kong & PostgreSQL Helm Charts ...."
# Install the Kong & PostgreSQL Helm Charts
# Install the KongHQ Helm chart
# helm install $RELEASE --namespace $NAMESPACE -f $GV -f $HERE/kong_value.yaml kong/kong
# Install the Bitnami Helm chart
helm install $RELEASE --namespace $NAMESPACE -f $GV -f $HERE/kong_value.yaml bitnami/kong

log "Waiting .... (up to 15 minutes) for pod ready status ...."
# Wait for the Kong pods to become available
wait_for_pod_ready 900 $RELEASE   # seconds

# Invocation to retrieve the PostgreSQL password
# kubectl get secret --namespace z2a-test acumos-kong-postgresql -o jsonpath="{.data.postgresql-password}" | base64 --decode
