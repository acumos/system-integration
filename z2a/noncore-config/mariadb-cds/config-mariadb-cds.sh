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
# Name: config-mariadb-cds.sh  - helper script to configure noncore MariaDB (CDS)

# Anchor the base directory for the util.sh helper
HERE=$(dirname $(readlink -f $0))
source $HERE/utils.sh
redirect_to $HERE/install.log

# Default values for Common Data Services (CDS)
# Edit these values for custom values
NAMESPACE=$(gv_read global.namespace)
RELEASE=$(gv_read global.acumosCdsDbService)

log "Preparing Database Files ...."
# Prepare db-files for the DB creation activity
# TODO: pull latest version of these SQL files from gerrit.acumos.org
cp $HERE/db-files/cmn-data-svc-base-mysql.sql $HERE/db-files/db-create.sql
cp $HERE/db-files/cmn-data-svc-ddl-dml.sql $HERE/db-files/db-init.sql

# Exports for mariaDB-exec scripts
export DB_USER=$(gv_read global.acumosCdsDbUserName)
export DB_PASSWORD=$(gv_read global.acumosCdsDbUserPassword)
export DB_NAME=$(gv_read global.acumosCdsDb)
export NAMESPACE RELEASE

# Inline Placeholder updates
sed -i -e "s/%CDS%/$DB_NAME/g" -e "s/%CDS_USER%/$DB_USER/g" -e "s/%CDS_PASS%/$DB_PASSWORD/g" $HERE/db-files/db-create.sql

log "Confirming MariaDB Service Availability (this may take a few minutes) ...."
# Confirm DB service availability before we connect to build the DB and load the DML
log "\c"
wait=900  # seconds
# see cds-root-exec.sh - connect timeout = 5 seconds
for i in $(seq $((wait/5)) -1 1) ; do
  logc ".\c"
  if echo "SELECT 1;" | $HERE/cds-root-exec.sh > /dev/null 2>&1 ; then break ; fi
  if [ $i -eq 1 ] ; then log "\nTimed out waiting on CDS DB ...." ; exit ; fi
  # sleep 5 - relying on connect timeout value
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
