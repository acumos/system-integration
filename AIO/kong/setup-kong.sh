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
#. What this is: script to setup the kong proxy for Acumos, under docker or k8s
#.
#. Prerequisites:
#. - Acumos core components through oneclick_deploy.sh
#.
#. Usage: intended to be called directly from oneclick_deploy.sh
#.

function clean() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any existing docker based components for kong-service"
    cs=$(docker ps -a | awk '/kong/{print $1}')
    for c in $cs; do
      docker stop $c
      docker rm $c
    done
  else
    log "Remove job kong-configure if running"
    stop_job kong-configure
    log "Stop any existing k8s based components for kong-service"
    if [[ ! -e deploy/kong-service.yaml ]]; then
      mkdir -p deploy
      cp -r kubernetes/* deploy/.
      replace_env deploy
    fi
    stop_service deploy/kong-admin-service.yaml
    stop_service deploy/kong-service.yaml
    stop_deployment deploy/kong-deployment.yaml
    log "Remove PVC for kong-service"
    delete_pvc kong-db $ACUMOS_NAMESPACE
    log "Remove configmap kong-config"
    if [[ $($k8s_cmd get configmap -n $ACUMOS_NAMESPACE kong-config) ]]; then
      $k8s_cmd delete configmap -n $ACUMOS_NAMESPACE kong-config
    fi
  fi
}

function setup() {
  trap 'fail' ERR

  log "Add the Acumos cert and key to the configuration data"
  cp ../certs/$ACUMOS_CERT config/.
  cp ../certs/$ACUMOS_CERT_KEY config/.

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Build the local configure-kong image"
    docker build -t kong-configure .
    log "Deploy the docker based components for kong"
    source docker-compose.sh up -d --build --force-recreate
    wait_running kong-service
  else
    log "Setup the kong-db PVC"
    setup_pvc kong-db $ACUMOS_NAMESPACE $KONG_DB_PV_SIZE

    log "Deploy the k8s based components for kong"
    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    replace_env deploy
    start_service deploy/kong-admin-service.yaml
    start_service deploy/kong-service.yaml
    start_deployment deploy/kong-deployment.yaml
    wait_running kong $ACUMOS_NAMESPACE

    log "Create the kong-config configmap"
    $k8s_cmd create configmap -n $ACUMOS_NAMESPACE kong-config --from-file=config

    log "Create the kong-configure job"
    $k8s_cmd create -f deploy/kong-configure-job.yaml
    wait_completed kong-configure
  fi
}

clean
setup
