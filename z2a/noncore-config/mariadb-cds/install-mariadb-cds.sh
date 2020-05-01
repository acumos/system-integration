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
# Name: install-mariadb-cds.sh  - helper script to install noncore MariaDB (CDS)

# Anchor the base directory for the util.sh helper
HERE=$(dirname $(readlink -f $0))
source $HERE/utils.sh
redirect_to $HERE/install.log

# Default values for Common Data Services (CDS)
# Edit these values for custom values
NAMESPACE=$(gv_read global.namespace)
RELEASE=$(gv_read global.acumosCdsDbService)

log "Adding Bitnami repo ...."
# Add Bitnami repo to Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Simple k/v map to set MariaDB configuration values
# These are override values for the default Bitnami chart.
CDS_PVC_SIZE=$(gv_read global.acumosCdsDbPvcStorage)
cat <<EOF | tee $HERE/cds_mariadb_value.yaml
nameOverride: $RELEASE
master:
  persistence:
    size: "$CDS_PVC_SIZE"
slave:
  persistence:
    size: "$CDS_PVC_SIZE"
EOF

log "Installing Bitnami MariaDB Helm Chart ...."
# Helm Chart Installation incantation
helm install $RELEASE --namespace $NAMESPACE -f $ACUMOS_GLOBAL_VALUE -f $HERE/cds_mariadb_value.yaml bitnami/mariadb

log "Waiting .... (up to 15 minutes) for pod ready status ...."
# Wait for the MariaDB-CDS pod to become ready
wait_for_pod_ready 900 $RELEASE

# Extract the DB root password from the K8s secrets ; insert the K/V into the global_values.yaml file
log "\c"
wait=180  # seconds
for i in $(seq $((wait/5)) -1 1) ; do
  logc ".\c"
  kubectl get secrets -A --namespace $NAMESPACE | grep -q ${RELEASE} && break
  if [ $i -eq 1 ] ; then log "\nTimeout on root password retrieval ...." ; exit ; fi
  sleep 5
done
logc ""

# Extract the DB root password from the K8s secrets ; insert the K/V into the global_values.yaml file
ROOT_PASSWORD=$(kubectl get secret --namespace $NAMESPACE $RELEASE -o jsonpath="{.data.mariadb-root-password}" | base64 --decode)
yq w -i $ACUMOS_GLOBAL_VALUE global.acumosCdsDbRootPassword $ROOT_PASSWORD
