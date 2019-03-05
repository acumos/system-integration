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
#   acumos-env.sh as updated by that script for deployment options.
#
# Usage: intended to be called directly from oneclick_deploy.sh, but can also
# be called directly if the following values are set in the shell environment,
# e.g. by sourcing the acumos-env.sh script as shown below:
# ACUMOS_CDS_DB
# ACUMOS_MARIADB_HOST
# ACUMOS_MARIADB_PORT
# ACUMOS_MARIADB_USER
# ACUMOS_MARIADB_USER_PASSWORD
#
# $ source acumos-env.sh
# $ bash setup-elk.sh [clean]
#   clean: (optional) clean the installation, delete the Helm release and PVC
#

# First define utils that will overridden below

function elk_fail() {
  set +x
  trap - ERR
  reason="$1"
  if [[ "$1" == "" ]]; then reason="unknown failure at $fname $fline"; fi
  log "$reason"
  sed -i -- 's/DEPLOY_RESULT=.*/DEPLOY_RESULT=fail/' $AIO_ROOT/elk-env.sh
  sed -i -- "s~FAIL_REASON=.*~FAIL_REASON=$reason~" $AIO_ROOT/elk-env.sh
  exit 1
}

function build_images() {
  trap 'elk_fail' ERR

  log "Prepare ELK stack component configs for AIO deploy"
  if [[ -d platform-oam ]]; then rm -rf platform-oam; fi
  git clone https://gerrit.acumos.org/r/platform-oam
  log "Correct references to elasticsearch-service for AIO deploy"
  sed -i -- 's/elasticsearch:9200/elasticsearch-service:9200/g' \
    platform-oam/elk-stack/logstash/pipeline/logstash.conf
  sed -i -- 's/elasticsearch:9200/elasticsearch-service:9200/g' \
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

function setup() {
  trap 'elk_fail' ERR
  local WORK_DIR=$(pwd)
  # acumos-env.sh will call elk-env.sh as setup by setup_prereqs.sh
  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    cd ../../charts/elk-stack
    cp $AIO_ROOT/elk-env.sh .
    source setup-elk.sh $K8S_DIST
  else
    log "Stop any existing docker based components for elk-stack"
    source docker-compose.sh down
    build_images
    source docker-compose.sh up -d --build --force-recreate
  fi

  log "Wait for all elk-stack pods to be Running"
  apps="elasticsearch kibana logstash"
  for app in $apps; do
    wait_running $app $ACUMOS_ELK_NAMESPACE
  done

  sed -i -- 's/DEPLOY_RESULT=.*/DEPLOY_RESULT=success/' $AIO_ROOT/elk-env.sh
  cd $WORK_DIR
}

if [[ "$AIO_ROOT" == "" ]]; then
  source ../acumos-env.sh
  source ../utils.sh
fi
setup
