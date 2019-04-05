#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2018-2019 AT&T Intellectual Property. All rights reserved.
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
#. What this is: script to setup the ELK stack for Acumos under docker or k8s
#
# Prerequisites:
# - Acumos platform core components installed per oneclick_deploy.sh, with
#   acumos_env.sh as updated by that script for deployment options.
#
# Usage:
# For docker-based deployments, run this script on the AIO host.
# For k8s-based deployment, run this script on the AIO host or a workstation
# connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
# $ bash setup_elk.sh <AIO_ROOT>
#   AIO_ROOT: path to AIO folder where environment files are
#

# First define utils that will overridden below

function elk_fail() {
  set +x
  trap - ERR
  reason="$1"
  if [[ "$1" == "" ]]; then reason="unknown failure at $fname $fline"; fi
  log "$reason"
  sedi 's/DEPLOY_RESULT=.*/DEPLOY_RESULT=fail/' $AIO_ROOT/elk_env.sh
  sedi "s~FAIL_REASON=.*~FAIL_REASON=$reason~" $AIO_ROOT/elk_env.sh
  exit 1
}

function build_images() {
  trap 'elk_fail' ERR

  log "Prepare ELK stack component configs for AIO deploy"
  if [[ -d platform-oam ]]; then rm -rf platform-oam; fi
  git clone https://gerrit.acumos.org/r/platform-oam
  log "Correct references to elasticsearch-service for AIO deploy"
  sedi 's/elasticsearch:9200/elasticsearch-service:9200/g' \
    platform-oam/elk-stack/logstash/pipeline/logstash.conf
  sedi 's/elasticsearch:9200/elasticsearch-service:9200/g' \
    platform-oam/elk-stack/kibana/config/kibana.yml

  log "Building local acumos-elasticsearch image"
  cd elasticsearch
  cp -r ../platform-oam/elk-stack/elasticsearch/config .
  docker build -t acumos-elasticsearch .

  log "Building local acumos-kibana image"
  # Pr https://www.elastic.co/guide/en/kibana/current/docker.html
  cd ../kibana
  cp -r ../platform-oam/elk-stack/kibana/config .
  docker build -t acumos-kibana .

  log "Building local acumos-logstash image"
  cd ../logstash
  cp -r ../platform-oam/elk-stack/logstash/config .
  cp -r ../platform-oam/elk-stack/logstash/pipeline .
  docker build -t acumos-logstash .
  cd ..
}

function setup_elk() {
  trap 'elk_fail' ERR
  local WORK_DIR=$(pwd)
  # acumos_env.sh will call elk_env.sh as setup by setup_prereqs.sh
  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    cd $AIO_ROOT/../charts/elk-stack
    cp $AIO_ROOT/elk_env.sh .
    bash setup_elk.sh $AIO_ROOT $K8S_DIST
  else
    log "Stop any existing docker based components for elk-stack"
    bash docker_compose.sh $AIO_ROOT down
    build_images
    bash docker_compose.sh $AIO_ROOT up -d --build --force-recreate
  fi

  log "Wait for all elk-stack pods to be Running"
  apps="elasticsearch kibana logstash"
  for app in $apps; do
    wait_running $app $ACUMOS_ELK_NAMESPACE
  done

  sedi 's/DEPLOY_RESULT=.*/DEPLOY_RESULT=success/' $AIO_ROOT/elk_env.sh
  cd $WORK_DIR
}

if [[ $# -lt 1 ]]; then
  cat <<'EOF'
Usage:
  For docker-based deployments, run this script on the AIO host.
  For k8s-based deployment, run this script on the AIO host or a workstation
  connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
  $ bash setup_elk.sh <AIO_ROOT>
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
cd $AIO_ROOT/elk-stack
setup_elk
cd $WORK_DIR
