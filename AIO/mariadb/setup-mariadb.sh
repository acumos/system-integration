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
#. What this is: script to setup the mariadb for Acumos, under docker or k8s
#.
#. Prerequisites:
#. - Acumos core components through oneclick_deploy.sh
#.
#. Usage: intended to be called directly from oneclick_deploy.sh
#. NOTE: Redeploying MariaDB with an existing DB is not yet supported
#.

function clean() {
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any existing docker based components for mariadb-service"
    source docker-compose.sh down
  else
    log "Stop any existing k8s based components for mariadb-service"
    stop_service deploy/mariadb-service.yaml
    stop_deployment deploy/mariadb-deployment.yaml
    log "Remove PVC for mariadb-service"
    source ../setup-pv.sh clean pvc mariadb-data $ACUMOS_NAMESPACE
  fi
}

function setup() {
  trap 'fail' ERR
  if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
    # Can only restart services etc if not redeploying with an existing DB
    clean
  fi

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    source docker-compose.sh up -d --build --force-recreate
  else
    log "Setup the mariadb-data PVC"
    source ../setup-pv.sh setup pvc mariadb-data \
      $ACUMOS_NAMESPACE $MARIADB_DATA_PV_SIZE

    if [[ "$K8S_DIST" == "openshift" ]]; then
      log "Workaround variation in OpenShift for external access to mariadb"
      sed -i -- 's/<ACUMOS_HOST>/172.17.0.1/' kubernetes/mariadb-deployment.yaml
    fi

    log "Deploy the k8s based components for maradb"
    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    replace_env deploy
    start_service deploy/mariadb-service.yaml
    start_deployment deploy/mariadb-deployment.yaml
  fi

  wait_running mariadb-service

  log "Wait for mariadb server to accept connections"
  while ! mysql -h $ACUMOS_HOST -P $ACUMOS_MARIADB_PORT --user=root \
    --password=$ACUMOS_MARIADB_PASSWORD -e "SHOW DATABASES;" ; do
    log "Mariadb server is not yet accepting connections from $HOST_IP"
    sleep 10
  done
}

update_env ACUMOS_MARIADB_PASSWORD $(uuidgen)
update_env ACUMOS_MARIADB_USER_PASSWORD $(uuidgen)
setup
