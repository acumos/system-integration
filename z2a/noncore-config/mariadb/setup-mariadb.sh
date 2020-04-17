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
#   # Expected Values from global_value.conf
    # acumosCdsDbPort: "3306"                     < deferred for this version
    # acumosCdsImage: "common-dataservice:3.1.0"
    # acumosCdsDb: "CDS"
    # acumosCdsUser: "ccds_client"
    # acumosCdsPassword: "ccds_client"
    # acumosCdsDbUserName: "CDS_USER"
    # acumosCdsDbUserPassword: "CDS_PASS"
    # acumosCdsDbRootPassword: "rootme"
    # acumosCdsDbPvcStorage: "1Gi"

# Anchor the base directory for the util.sh helper
HERE=$(dirname $(readlink -f $0))
source $HERE/utils.sh
redirect_to $HERE/install.log

# Default values for Acumos MariaDB - in support of Common Data Services (CDS)
# Edit these values for custom values
NAMESPACE=$(gv_read global.namespace)
RELEASE=$(gv_read global.acumosCdsDbService)

log "Adding Bitnami repo ...."
# Add Bitnami repo to Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Simple k/v map to set MariaDB configuration values
# These are override values for the default Bitnami chart.
cat <<EOF | tee $HERE/cds_mariadb_value.yaml
nameOverride: $RELEASE
master:
  persistence:
    size: 1Gi
slave:
  persistence:
    size: 1Gi
EOF

log "Installing Bitnami MariaDB Helm Chart ...."
# Helm Chart Installation incantation
helm install $RELEASE --namespace $NAMESPACE -f $ACUMOS_GLOBAL_VALUE -f $HERE/cds_mariadb_value.yaml bitnami/mariadb

# Extract the DB root password from the K8s secrets ; insert the K/V into the global_values.yaml file
log "\c"
for i in $(seq 1 20) ; do
  sleep 10
  logc ".\c"
  kubectl get secrets -A --namespace $NAMESPACE | grep -q ${RELEASE} && break
  if [ $i -eq 20 ] ; then log "\nTimeout on root password retrieval ...." ; exit ; fi
done
logc ""

# Extract the DB root password from the K8s secrets ; insert the K/V into the global_values.yaml file
ROOT_PASSWORD=$(kubectl get secret --namespace $NAMESPACE $RELEASE -o jsonpath="{.data.mariadb-root-password}" | base64 --decode)
yq w -i $ACUMOS_GLOBAL_VALUE global.acumosCdsDbRootPassword $ROOT_PASSWORD

log "Preparing Database Files ...."
# Prepare db-files for the DB creation activity
# TODO: pull latest version of these SQL files from gerrit.acumos.org
cp $HERE/db-files/cmn-data-svc-base-mysql.sql $HERE/db-files/db-create.sql
cp $HERE/db-files/cmn-data-svc-ddl-dml.sql $HERE/db-files/db-init.sql

export DB_USER=$(gv_read global.acumosCdsDbUserName)
export DB_PASSWORD=$(gv_read global.acumosCdsDbUserPassword)
export DB_NAME=$(gv_read global.acumosCdsDb)

# Inline Placeholder updates
sed -i -e "s/%CDS%/$DB_NAME/g" -e "s/%CDS_USER%/$DB_USER/g" -e "s/%CDS_PASS%/$DB_PASSWORD/g" $HERE/db-files/db-create.sql

log "Confirming MariaDB Service Availability .... (this may take a few minutes) ...."
# Confirm DB service availability before we connect to build the DB and load the DML
log "\c"
for i in $(seq 1 20) ; do
  sleep 10
  logc ".\c"
  if echo "SELECT 1;" | $HERE/cds-root-exec.sh > /dev/null 2>&1 ; then break ; fi
  if [ $i -eq 20 ] ; then log "\nTimed out waiting on CDS DB ...." ; exit ; fi
done
logc ""

log "Creating CDS Database ...."
# Create the CDS DB
$HERE/cds-root-exec.sh < $HERE/db-files/db-create.sql

log "Applying CDS DDL/DML ...."
# Apply DDL/DML to the CDS Database
$HERE/cds-user-exec.sh < $HERE/db-files/db-init.sql

log "Verify CDS Database ...."
# Verify that the CDS Database has been created, and the DDL/DML has been applied
$HERE/cds-root-exec.sh < $HERE/db-files/db-verify.sql
