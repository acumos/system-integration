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
# What this is: script to setup the mariadb for Acumos, under docker
#
# Prerequisites:
# - Acumos core components through oneclick_deploy.sh
#
# Usage:
# For docker-based deployments, run this script on the AIO host.
# $ bash setup_mariadb.sh
#
# NOTE: Redeploying MariaDB with an existing DB is not yet supported
#

function clean_mariadb() {
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any existing docker based components for mariadb-service"
    bash docker_compose.sh down
  else
    delete_namespace $ACUMOS_MARIADB_NAMESPACE
  fi
}

function setup_mariadb() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    bash docker_compose.sh up -d --build --force-recreate
    wait_running mariadb-service
  else
    create_namespace $ACUMOS_MARIADB_NAMESPACE
    log "Setup the mariadb-data PVC"
    setup_pvc mariadb-data $ACUMOS_MARIADB_NAMESPACE $MARIADB_DATA_PV_SIZE

    log "Deploy the k8s based components for mariadb"
    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    replace_env deploy
    start_service deploy/mariadb-service.yaml
    start_deployment deploy/mariadb-deployment.yaml
    wait_running mariadb $ACUMOS_MARIADB_NAMESPACE
  fi

  log "Wait for mariadb server to accept connections"
  i=0
  while ! mysql -h $ACUMOS_MARIADB_HOST_IP -P $ACUMOS_MARIADB_PORT --user=root \
  --password=$ACUMOS_MARIADB_PASSWORD -e "SHOW DATABASES;" ; do
    i=$((i+1))
    if [[ $i -gt 30 ]]; then
      fail "MariaDB failed to respond after 5 minutes"
    fi
    log "Mariadb server is not yet accepting connections from $ACUMOS_MARIADB_ADMIN_HOST"
    sleep 10
  done
}

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ..; pwd -P)"; fi
source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh
clean_mariadb
setup_mariadb
cd $WORK_DIR
