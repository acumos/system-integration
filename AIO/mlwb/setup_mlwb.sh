#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2019 AT&T Intellectual Property. All rights reserved.
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
# What this is: Deployment script for Acumos MLWB components
#
# Prerequisites:
# - Acumos deployed under docker or k8s via the AIO toolset
#
# Usage:
# $ bash setup_mlwb.sh <AIO_ROOT>
#   AIO_ROOT: path to AIO folder where environment files are

clean_resource() {
  rss=$($k8s_cmd get $1 -n $ACUMOS_NAMESPACE  | awk '/mlwb/{print $1}')
  for rs in $rss; do
    $k8s_cmd delete $1 -n $ACUMOS_NAMESPACE $rs
    while [[ $($k8s_cmd get $1 -n $ACUMOS_NAMESPACE $rs) ]]; do
      sleep 5
    done
  done
}

function clean_mlwb() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any existing docker based components for mlwb"
    cs=$(docker ps -a | awk '/mlwb/{print $1}')
    for c in $cs; do
      docker stop $c
      docker rm $c
    done
  else
    log "Stop any existing k8s based components for NiFi"
    trap - ERR
    rm -rf deploy
    log "Delete all MLWB resources"
    clean_resource deployment
    clean_resource pods
    clean_resource service
    clean_resource configmap
    clean_resource ingress
    clean_resource secret
    trap 'fail' ERR
  fi

  log "Cleanup docker images in case we need to redownload an image"
  docker image prune -a -f
}

setup_mlwb() {
  trap 'fail' ERR

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Deploy MLWB docker-based components"
    bash docker_compose.sh $AIO_ROOT up -d --build
  else
    if [[ ! -e deploy ]]; then mkdir deploy; fi
    rm -f deploy/*
    cp kubernetes/* deploy/.

    log "Set variable values in k8s templates"
    replace_env deploy

    log "Deploy the MLWB k8s-based components"
    # Create services first... see https://github.com/kubernetes/kubernetes/issues/16448
    for f in  deploy/*-ingress.yaml ; do
      log "Creating ingress from $f"
      $k8s_cmd create -f $f
    done
    for f in  deploy/*-service.yaml ; do
      log "Creating service from $f"
      $k8s_cmd create -f $f
    done
    for f in  deploy/*-deployment.yaml ; do
      log "Creating deployment from $f"
      $k8s_cmd create -f $f
    done

    log "Wait for all MLWB core pods to be Running"
    apps="mlwb-dashboard-webcomponent mlwb-home-webcomponent \
mlwb-project mlwb-project-webcomponent mlwb-project-catalog-webcomponent \
mlwb-notebook mlwb-notebook-webcomponent mlwb-notebook-catalog-webcomponent \
mlwb-pipeline mlwb-pipeline-webcomponent mlwb-pipeline-catalog-webcomponent"
    for app in $apps; do
      wait_running $app $ACUMOS_NAMESPACE
    done
  fi
}

if [[ $# -lt 1 ]]; then
  cat <<'EOF'
Usage:
  $ bash setup_mlwb.sh <AIO_ROOT>
    AIO_ROOT: path to AIO folder where environment files are
EOF
  echo "All parameters not provided"
  exit 1
fi

set -x
WORK_DIR=$(pwd)
export AIO_ROOT=$1
source $AIO_ROOT/acumos_env.sh
source $AIO_ROOT/utils.sh
cd $(dirname "$0")
source mlwb_env.sh
trap 'fail' ERR
if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
  log "Deploy NiFi"
  bash nifi/setup_nifi.sh $AIO_ROOT
  bash $AIO_ROOT/../charts/jupyterhub/setup_jupyterhub.sh $AIO_ROOT/acumos_env.sh
fi
log "Apply NiFi updates to mlwb_env.sh"
source mlwb_env.sh
clean_mlwb
setup_mlwb
cd $WORK_DIR
