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
# What this is: script to setup the kong proxy for Acumos, under docker
#
# Prerequisites:
# - Acumos core components through oneclick_deploy.sh
#
# Usage:
# For docker-based deployments, run this script on the AIO host.
# For k8s-based deployment, run this script on the AIO host or a workstation
# connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
# $ bash setup_kong.sh [setup|clean|all]
#  setup: setup the kong components
#  clean: stop the kong components
#  all: (default) stop and setup
#

function clean_kong() {
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
    if kubectl delete ingress -n $ACUMOS_NAMESPACE kong-ingress; then
      log "Ingress kong-ingress deleted"
    fi
    if [[ $(kubectl delete secret -n $ACUMOS_NAMESPACE ingress-cert) ]]; then
      log "Secret ingress-cert deleted"
    fi
    log "Remove PVC for kong-service"
    delete_pvc $KONG_DB_PVC_NAME $ACUMOS_NAMESPACE
    log "Remove configmap kong-config"
    if $k8s_cmd get configmap -n $ACUMOS_NAMESPACE kong-config; then
      $k8s_cmd delete configmap -n $ACUMOS_NAMESPACE kong-config
    fi
  fi
}

function setup_kong() {
  trap 'fail' ERR

  log "Add the Acumos cert and key to the configuration data"
  cp ../certs/$ACUMOS_CERT config/.
  cp ../certs/$ACUMOS_CERT_KEY config/.

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Build the local configure-kong image"
    docker build -t kong-configure .
    log "Deploy the docker based components for kong"
    bash docker_compose.sh up -d --build --force-recreate
    wait_running kong-service
    local secs=0
    while [[ $(docker ps -a | grep kong-configure | grep -c 'Exited') -eq 0 ]]; do
      log "Waiting 10 seconds for kong-configure job to complete"
      sleep 10
      secs=$((secs+10))
      if [[ $secs -eq "$ACUMOS_SUCCESS_WAIT_TIME" ]]; then
        fail "kong-configure job failed to complete"
      fi
    done
  else
    log "Setup the $KONG_DB_PVC_NAME PVC"
    setup_pvc $ACUMOS_NAMESPACE $KONG_DB_PVC_NAME $KONG_DB_PV_NAME \
      $KONG_DB_PV_SIZE $KONG_DB_PV_CLASSNAME
    create_ingress_cert_secret $ACUMOS_NAMESPACE config/$ACUMOS_CERT config/$ACUMOS_CERT_KEY

    if [[ "$ACUMOS_KONG_HTTPS_ONLY" == "false" ]]; then
      log "Update Kong configuration to disable 'https_only' since Kong is deployed behind an ingress controller"
      local files="$(ls config/*.json)"
      for f in $files; do
        sedi 's/\"https_only\": .*/\"https_only\": false,/' $f
      done
    fi
    log "Update internal address of Jenkins as deployed by Helm"
    sedi "s/jenkins-service/$ACUMOS_NAMESPACE-jenkins/" config/jenkins.json

    log "Deploy the k8s based components for kong"
    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    replace_env deploy
    start_service deploy/kong-admin-service.yaml
    start_service deploy/kong-service.yaml
    start_deployment deploy/kong-deployment.yaml
    wait_running kong $ACUMOS_NAMESPACE

    log "Create Kong ingress rule"
    kubectl create -f deploy/kong-ingress.yaml

    log "Create the kong-config configmap"
    $k8s_cmd create configmap -n $ACUMOS_NAMESPACE kong-config --from-file=config

    log "Create the kong-configure job"
    $k8s_cmd create -f deploy/kong-configure-job.yaml
    wait_completed kong-configure
  fi
}

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ..; pwd -P)"; fi
source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh
action=$1
if [[ "$action" == "" ]]; then action=all; fi
if [[ "$action" == "clean" || "$action" == "all" ]]; then clean_kong; fi
if [[ "$action" == "setup" || "$action" == "all" ]]; then setup_kong; fi
cd $WORK_DIR
