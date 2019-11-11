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
# What this is: script to setup Acumos database
#
# Prerequisites:
# - acumos_env.sh script prepared through oneclick_deploy.sh or manually, to
#   set install options (e.g. docker/k8s)
#
# Usage:
#   For docker-based deployments, run this script on the AIO host.
#   For k8s-based deployment, run this script on the AIO host or a workstation
#   connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
#   $ bash setup_acumosdb.sh
#

function clean_db() {
  trap 'fail' ERR
  if [[ "$ACUMOS_MARIADB_ROOT_ACCESS" == "true" ]]; then
    log "Remove Acumos databases if present in MariaDB"
    if [[ $(mysql $server --user=root --password=$ACUMOS_MARIADB_PASSWORD -e "DROP DATABASE $ACUMOS_CDS_DB;") ]]; then
      log "Database $ACUMOS_CDS_DB dropped"
    fi
    log "Create database $ACUMOS_CDS_DB"
    mysql $server --user=root --password=$ACUMOS_MARIADB_PASSWORD \
      -e "CREATE DATABASE $ACUMOS_CDS_DB; USE $ACUMOS_CDS_DB; GRANT ALL PRIVILEGES ON $ACUMOS_CDS_DB.* TO \"$ACUMOS_MARIADB_USER\"@'%' IDENTIFIED BY \"$ACUMOS_MARIADB_USER_PASSWORD\";"
  else
    local tables=$(mysql $server --user=$ACUMOS_MARIADB_USER --password=$ACUMOS_MARIADB_USER_PASSWORD -e "use $ACUMOS_CDS_DB; show tables;" | grep -i C_ | awk '{print $1}')
    if [[ "$tables" != "" ]]; then
      cmd="USE $ACUMOS_CDS_DB; SET FOREIGN_KEY_CHECKS = 0;"
      for table in $tables; do
        cmd="$cmd DROP TABLE \`$table\`; "
      done
      cmd="$cmd SET FOREIGN_KEY_CHECKS = 1;"
      echo "$cmd"
      mysql $server --user=$ACUMOS_MARIADB_USER \
        --password=$ACUMOS_MARIADB_USER_PASSWORD \
        -e "$cmd"
    fi
  fi
}

function new_db() {
  trap 'fail' ERR
  log "Setting up Acumos database for CDS version $ACUMOS_CDS_VERSION"
  if [[ "$ACUMOS_MARIADB_ROOT_ACCESS" == "true" ]]; then
    log "Setup user for access to database $ACUMOS_CDS_DB"
    mysql $server --user=root --password=$ACUMOS_MARIADB_PASSWORD \
      -e "USE $ACUMOS_CDS_DB; GRANT ALL PRIVILEGES ON $ACUMOS_CDS_DB.* TO \"$ACUMOS_MARIADB_USER\"@'%' IDENTIFIED BY \"$ACUMOS_MARIADB_USER_PASSWORD\";"
  fi
  # NOTE: user and default database was created in the process of server creation
  log "Retrieve and customize database script for CDS version $ACUMOS_CDS_VERSION"
  # NOTE: Naming convention change in sql scripts as of 3.0-rev2 !
  # See https://github.com/acumos/common-dataservice/tree/master/cmn-data-svc-server/db-scripts
  if [[ $(ls cmn-data-svc-ddl-dml-*) != "" ]]; then rm cmn-data-svc-ddl-dml-*; fi
  wget https://raw.githubusercontent.com/acumos/common-dataservice/master/cmn-data-svc-server/db-scripts/cmn-data-svc-ddl-dml-$ACUMOS_CDS_VERSION.sql
  sedi "1s/^/use $ACUMOS_CDS_DB;\n/" cmn-data-svc-ddl-dml-$ACUMOS_CDS_VERSION.sql
  mysql $server --user=$ACUMOS_MARIADB_USER --password=$ACUMOS_MARIADB_USER_PASSWORD < cmn-data-svc-ddl-dml-$ACUMOS_CDS_VERSION.sql
}

function upgrade_db() {
  trap 'fail' ERR
  log "Upgrading database from CDS version $ACUMOS_CDS_PREVIOUS_VERSION to $ACUMOS_CDS_VERSION"
  upgrade="cmn-data-svc-upgrade-${ACUMOS_CDS_PREVIOUS_VERSION}-to-${ACUMOS_CDS_VERSION}.sql"
  if [[ $(ls ${upgrade}*) != "" ]]; then rm ${upgrade}*; fi
  wget https://raw.githubusercontent.com/acumos/common-dataservice/master/cmn-data-svc-server/db-scripts/$upgrade
  if [[ -e $upgrade ]]; then
    sedi "1s/^/use $ACUMOS_CDS_DB;\n/" $upgrade
    mysql $server --user=$ACUMOS_MARIADB_USER --password=$ACUMOS_MARIADB_USER_PASSWORD < $upgrade
  else
    fail "No available upgrade script for CDS upgrade from $ACUMOS_CDS_PREVIOUS_VERSION to $ACUMOS_CDS_VERSION"
  fi
}

function setup_acumosdb() {
  trap 'fail' ERR
  server="-h $ACUMOS_MARIADB_HOST -P 3306"
  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    if [[ "$ACUMOS_DEPLOY_AS_POD" == "false" || "$ACUMOS_MARIADB_HOST" != "$ACUMOS_INTERNAL_MARIADB_HOST" ]]; then
      server="-h $ACUMOS_MARIADB_DOMAIN -P $ACUMOS_MARIADB_NODEPORT"
    fi
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

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
source utils.sh
source acumos_env.sh
setup_acumosdb
cd $WORK_DIR
