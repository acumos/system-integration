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
#.
#. Prerequisites:
#. - Acumos platform core components installed per oneclick_deploy.sh, with
#.   acumos-env.sh as updated by that script for deployment options.
#.
#. Usage:
#. $ bash deploy-elk.sh
#.

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

  log "Building local acumos-filebeat image"
  # Per https://www.elastic.co/guide/en/beats/filebeat/current/running-on-docker.html
  cd ../filebeat
  cp -R ../platform-oam/filebeat/config .
  sudo docker build -t acumos-filebeat .

  log "Building local acumos-metricbeat image"
  cd ../metricbeat
  # fix bug in metricbeat.yaml
  sed -i -- 's/{ELASTICSEARCH_HOST}:5601/{KIBANA_HOST}:${KIBANA_PORT}/' \
    ../platform-oam/metricbeat/config/metricbeat.yml
  cp -R ../platform-oam/metricbeat/config .
  cp -R ../platform-oam/metricbeat/module.d .
  sudo docker build -t acumos-metricbeat .
  cd ..
}

function clean() {
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any existing docker based components for elk-stack"
    sudo bash docker-compose.sh $AIO_ROOT down
  else
    log "Stop any existing k8s based components for elk-stack"
    for comp in $comps; do
      stop_service deploy/$comp-service.yaml
      stop_deployment deploy/$comp-deployment.yaml
    done
  fi

  # Remove any existing ELK data only if not redeploying
  if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
    log "Remove any existing PV data for elasticsearch-service"
    bash $AIO_ROOT/setup-pv.sh clean pvc elasticsearch-data
    bash $AIO_ROOT/setup-pv.sh clean pv elasticsearch-data
  fi
}

function setup() {
  clean
  build_images

  # Per https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html
  log "Setup the elasticsearch-data PV"
  bash $AIO_ROOT/setup-pv.sh setup pv elasticsearch-data \
    $PV_SIZE_ACUMOS_ELASTICSEARCH_DATA "1000:1000"

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    sudo bash docker-compose.sh $AIO_ROOT up -d --build --force-recreate
  else
    log "Setup the elasticsearch-data PVC"
    bash $AIO_ROOT/setup-pv.sh setup pvc \
      elasticsearch-data $PV_SIZE_ACUMOS_ELASTICSEARCH_DATA

    log "Deploy the k8s based components for elk-stack"
    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    replace_env deploy
    log "Deploy the k8s based components for docker-proxy"
    for comp in $comps; do
      start_service deploy/$comp-service.yaml
      start_deployment deploy/$comp-deployment.yaml
    done
  fi

  log "Wait for all elk-stack pods to be Running"
  if [[ "$ACUMOS_DEPLOY_METRICBEAT" == "true" ]]; then
    apps="elasticsearch kibana logstash filebeat metricbeat"
  else
    apps="elasticsearch kibana logstash filebeat"
  fi
  for app in $apps; do
    wait_running $app
  done
}

source $AIO_ROOT/acumos-env.sh
source elk-env.sh
source $AIO_ROOT/utils.sh
if [[ "$ACUMOS_DEPLOY_METRICBEAT" == "true" ]]; then
  comps="elk filebeat metricbeat"
else
  comps="elk filebeat"
fi
setup
