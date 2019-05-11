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
# $ bash setup_kong.sh <AIO_ROOT>
#   AIO_ROOT: path to AIO folder where environment files are
#

function clean_kong() {
  trap 'fail' ERR
  log "Stop any existing docker based components for kong-service"
  cs=$(docker ps -a | awk '/kong/{print $1}')
  for c in $cs; do
    docker stop $c
    docker rm $c
  done
}

function setup_kong() {
  trap 'fail' ERR

  log "Add the Acumos cert and key to the configuration data"
  cp ../certs/$ACUMOS_CERT config/.
  cp ../certs/$ACUMOS_CERT_KEY config/.

  log "Build the local configure-kong image"
  docker build -t kong-configure .
  log "Deploy the docker based components for kong"
  bash docker_compose.sh $AIO_ROOT up -d --build --force-recreate
  wait_running kong-service
}

if [[ $# -lt 1 ]]; then
  cat <<'EOF'
Usage:
  For docker-based deployments, run this script on the AIO host.
  For k8s-based deployment, run this script on the AIO host or a workstation
  connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
  $ bash setup_kong.sh <AIO_ROOT>
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
cd $AIO_ROOT/kong
clean_kong
setup_kong
cd $WORK_DIR
