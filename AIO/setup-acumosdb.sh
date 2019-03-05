#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2018 AT&T Intellectual Property. All rights reserved.
# ===================================================================================
# This Acumos software file is distributed by AT&T
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
#. What this is: script to setup Acumos database
#.
#. Prerequisites:
#. - acumos-env.sh script prepared through oneclick_deploy.sh or manually, to
#.   set install options (e.g. docker/k8s)
#.
#. Usage: intended to be called directly from oneclick_deploy.sh
#.

function clean_db() {
  trap 'fail' ERR
  log "Remove Acumos databases if present in MariaDB"
  if [[ $(mysql $server --user=root --password=$ACUMOS_MARIADB_PASSWORD -e "DROP DATABASE $ACUMOS_CDS_DB;") ]]; then
    log "Database $ACUMOS_CDS_DB dropped"
  fi
  if [[ $(mysql $server --user=root --password=$ACUMOS_MARIADB_PASSWORD -e "DROP DATABASE $ACUMOS_CMS_DB;") ]]; then
    log "Database $ACUMOS_CMS_DB dropped"
  fi
  log "Create database $ACUMOS_CDS_DB"
  mysql $server --user=root --password=$ACUMOS_MARIADB_PASSWORD \
    -e "CREATE DATABASE $ACUMOS_CDS_DB; USE $ACUMOS_CDS_DB; GRANT ALL PRIVILEGES ON $ACUMOS_CDS_DB.* TO \"$ACUMOS_MARIADB_USER\"@'%' IDENTIFIED BY \"$ACUMOS_MARIADB_USER_PASSWORD\";"
}

function new_db() {
  trap 'fail' ERR
  log "Setting up Acumos database for CDS version $ACUMOS_CDS_VERSION"
  # NOTE: user and default database was created in the process of server creation
  log "Setup user for access to database $ACUMOS_CDS_DB"
  mysql $server --user=root --password=$ACUMOS_MARIADB_PASSWORD \
    -e "USE $ACUMOS_CDS_DB; GRANT ALL PRIVILEGES ON $ACUMOS_CDS_DB.* TO \"$ACUMOS_MARIADB_USER\"@'%' IDENTIFIED BY \"$ACUMOS_MARIADB_USER_PASSWORD\";"

  log "Retrieve and customize database script for CDS version $ACUMOS_CDS_VERSION"
  if [[ $(ls cmn-data-svc-ddl-dml-mysql*) != "" ]]; then rm cmn-data-svc-ddl-dml-mysql*; fi
  wget https://raw.githubusercontent.com/acumos/common-dataservice/master/cmn-data-svc-server/db-scripts/cmn-data-svc-ddl-dml-mysql-$ACUMOS_CDS_VERSION.sql
  sedi "1s/^/use $ACUMOS_CDS_DB;\n/" cmn-data-svc-ddl-dml-mysql-$ACUMOS_CDS_VERSION.sql
  mysql $server --user=$ACUMOS_MARIADB_USER --password=$ACUMOS_MARIADB_USER_PASSWORD < cmn-data-svc-ddl-dml-mysql-$ACUMOS_CDS_VERSION.sql

  log "Create database $ACUMOS_CMS_DB"
  mysql $server --user=root --password=$ACUMOS_MARIADB_PASSWORD \
    -e "CREATE DATABASE $ACUMOS_CMS_DB; USE $ACUMOS_CMS_DB; GRANT ALL PRIVILEGES ON $ACUMOS_CMS_DB.* TO \"$ACUMOS_MARIADB_USER\"@'%' IDENTIFIED BY \"$ACUMOS_MARIADB_USER_PASSWORD\";"
}

function upgrade_db() {
  trap 'fail' ERR
  log "Upgrading database from CDS version $ACUMOS_CDS_PREVIOUS_VERSION to $ACUMOS_CDS_VERSION"
  upgrade="cds-mysql-upgrade-${ACUMOS_CDS_PREVIOUS_VERSION}-to-${ACUMOS_CDS_VERSION}.sql"
  if [[ $(ls ${upgrade}*) != "" ]]; then rm ${upgrade}*; fi
  if [[ $(wget https://raw.githubusercontent.com/acumos/common-dataservice/master/cmn-data-svc-server/db-scripts/$upgrade) ]]; then
    sedi "1s/^/use $ACUMOS_CDS_DB;\n/" $upgrade
    mysql $server --user=$ACUMOS_MARIADB_USER --password=$ACUMOS_MARIADB_USER_PASSWORD < $upgrade
  else
    fail "No available upgrade script for CDS upgrade from $ACUMOS_CDS_VERSION to $ACUMOS_CDS_PREVIOUS_VERSION"
  fi
}

function setup() {
  trap 'fail' ERR
  if [[ "$ACUMOS_MARIADB" != "on-host" ]]; then
    server="-h $ACUMOS_MARIADB_HOST_IP -P $ACUMOS_MARIADB_PORT"
  fi

  if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
    clean_db
    new_db
  elif [[ "$ACUMOS_CDS_PREVIOUS_VERSION" != "$ACUMOS_CDS_VERSION" ]]; then
    upgrade_db
  else
    log "Redeploying with existing database version - no action required."
  fi
}

setup
