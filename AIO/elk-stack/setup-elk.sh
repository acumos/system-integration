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
#. What this is: script to setup the ELK stack for Acumos under docker or k8s
#
# Prerequisites:
# - Acumos platform core components installed per oneclick_deploy.sh, with
#   acumos-env.sh as updated by that script for deployment options.
#
# Usage: intended to be called directly from oneclick_deploy.sh
#

function build_images() {
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
  sudo docker build -t acumos-elasticsearch .

  log "Building local acumos-kibana image"
  # Pr https://www.elastic.co/guide/en/kibana/current/docker.html
  cd ../kibana
  cp -r ../platform-oam/elk-stack/kibana/config .
  sudo docker build -t acumos-kibana .

  log "Building local acumos-logstash image"
  cd ../logstash
  cp -r ../platform-oam/elk-stack/logstash/config .
  cp -r ../platform-oam/elk-stack/logstash/pipeline .
  sudo docker build -t acumos-logstash .

  cd ..
}

function clean() {
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any existing docker based components for elk-stack"
    sudo bash docker-compose.sh down
  else
    log "Stop any existing k8s based components for elk-stack"
    stop_service deploy/\elk-service.yaml
    stop_deployment deploy/elk-deployment.yaml
    log "Removing PVC for elk-stack"
    source ../setup-pv.sh clean pvc elasticsearch-data $ACUMOS_ELK_NAMESPACE
  fi
}

function setup() {
  build_images

  clean
  # Per https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html
  log "Setup the elasticsearch-data PV"
  source ../setup-pv.sh setup pv elasticsearch-data \
    $ACUMOS_ELK_NAMESPACE $ACUMOS_ELASTICSEARCH_DATA_PV_SIZE "1000:1000"

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    sudo bash docker-compose.sh up -d --build --force-recreate
  else
    if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
    log "Setup the elasticsearch-data PVC"
      source ../setup-pv.sh setup pvc elasticsearch-data \
        $ACUMOS_ELK_NAMESPACE $ACUMOS_ELASTICSEARCH_DATA_PV_SIZE \
        "$ACUMOS_ELK_HOST_USER:$ACUMOS_ELK_HOST_USER"
    fi

    log "Deploy the k8s based components for elk-stack"
    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    replace_env deploy
    log "Deploy the k8s based components for elk-stack"
    start_service deploy/elk-service.yaml
    start_deployment deploy/elk-deployment.yaml
  fi

  log "Wait for all elk-stack pods to be Running"
  apps="elasticsearch kibana logstash"
  for app in $apps; do
    wait_running $app
  done
}

source ../acumos-env.sh
source elk-env.sh
source ../utils.sh
setup
