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
# - acumos_env.sh customized for this platform, as by oneclick_deploy.sh
#
# Usage:
# For docker-based deployments, run this script on the AIO host.
# $ bash setup_docker_engine.sh <AIO_ROOT>
#   AIO_ROOT: path to AIO folder where environment files are
#

function clean_docker_engine() {
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

function setup_docker_engine() {
  trap 'fail' ERR
  log "Setup the $ACUMOS_NAMESPACE-docker-volume PVC"
  setup_pvc docker-volume $ACUMOS_NAMESPACE $DOCKER_VOLUME_PV_SIZE

  log "Deploy the k8s based components for docker-service"
  mkdir -p deploy
  cp -r kubernetes/* deploy/.
  replace_env deploy

  start_service deploy/docker-service.yaml
  start_deployment deploy/docker-deployment.yaml
  wait_running docker-dind $ACUMOS_NAMESPACE
}

if [[ $# -lt 1 ]]; then
  cat <<'EOF'
Usage:
  For docker-based deployments, run this script on the AIO host.
  For k8s-based deployment, run this script on the AIO host or a workstation
  connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
  $ bash setup_docker_engine.sh <AIO_ROOT>
    AIO_ROOT: path to AIO folder where environment files are
EOF
  echo "All parameters not provided"
  exit 1
fi

WORK_DIR=$(pwd)
export AIO_ROOT=$1
source $AIO_ROOT/acumos_env.sh
source $AIO_ROOT/utils.sh
trap 'fail' ERR
cd $AIO_ROOT/docker-engine
clean_docker_engine
setup_docker_engine
cd $WORK_DIR
