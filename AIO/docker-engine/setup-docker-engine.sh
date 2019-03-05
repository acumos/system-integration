#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
# What this is: Deployment script for the docker-engine and API server as a
# dependency of the Acumos platform.
#
# Prerequisites:
# - Ubuntu Xenial or Centos 7 server
# - acumos-env.sh customized for this platform, as by oneclick_deploy.sh
#
# Usage: intended to be called from oneclick_deploy.sh
#

function clean() {
  trap 'fail' ERR
  log "Stop any existing k8s based components for docker-service"
  if [[ ! -e deploy/docker-service.yaml ]]; then
    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    replace_env deploy
  fi
  stop_service deploy/docker-service.yaml
  stop_deployment deploy/docker-deployment.yaml
  log "Removing PVC for docker-engine"
  delete_pvc docker-volume $ACUMOS_NAMESPACE
}

function setup() {
  trap 'fail' ERR
  log "Setup the $ACUMOS_NAMESPACE-docker-volume PVC"
  setup_pvc docker-volume $ACUMOS_NAMESPACE $DOCKER_VOLUME_PV_SIZE

  log "Deploy the k8s based components for docker-service"
  mkdir -p deploy
  cp -r kubernetes/* deploy/.
  replace_env deploy

  start_service deploy/docker-service.yaml
  start_deployment deploy/docker-deployment.yaml
  wait_running docker $ACUMOS_NAMESPACE
}

if [[ "$1" == "clean" ]]; then
  clean
else
  clean
  setup
fi
