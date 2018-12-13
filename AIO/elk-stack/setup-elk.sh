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

function setup() {
  log "Stop ELK stack components"
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    sudo bash docker-compose.sh $AIO_ROOT down
  else
    if [[ "ACUMOS_DEPLOY_METRICBEAT" == "true" ]]; then
      comps="elk filebeat metricbeat"
    else
      comps="elk filebeat"
    fi
    for comp in $comps; do
      stop_service deploy/$comp-service.yaml
      stop_deployment deploy/$comp-deployment.yaml
      log "Delete the acumos-elasticsearch-data PVC"
      bash $AIO_ROOT/setup-pv.sh clean pvc elasticsearch-data
    done
  fi

  build_images

  # Per https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html
  log "Setup the acumos-elasticsearch-data PV"
  bash $AIO_ROOT/setup-pv.sh setup pv elasticsearch-data \
    $PV_SIZE_ACUMOS_ELASTICSEARCH_DATA "1000:1000"

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    sudo bash docker-compose.sh $AIO_ROOT up -d --build --force-recreate
  else
    log "Setup the acumos-elasticsearch-data PVC"
    bash $AIO_ROOT/setup-pv.sh setup pvc \
      acumos-elasticsearch-data $PV_SIZE_ACUMOS_ELASTICSEARCH_DATA

    log "Deploy the k8s based components for elk-stack"
    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    replace_env deploy "ACUMOS_CDS_DB ACUMOS_ELK_DOMAIN \
      ACUMOS_ELK_ELASTICSEARCH_PORT ACUMOS_ELK_ES_JAVA_HEAP_MAX_SIZE \
      ACUMOS_ELK_ES_JAVA_HEAP_MIN_SIZE ACUMOS_ELK_HOST ACUMOS_ELK_KIBANA_NODEPORT \
      ACUMOS_ELK_KIBANA_PORT ACUMOS_ELK_LOGSTASH_HOST ACUMOS_ELK_LOGSTASH_PORT \
      ACUMOS_ELK_LS_JAVA_HEAP_MAX_SIZE ACUMOS_ELK_LS_JAVA_HEAP_MIN_SIZE \
      ACUMOS_NAMESPACE ACUMOS_ELK_NODEPORT ACUMOS_FILEBEAT_PORT \
      ACUMOS_MARIADB_HOST ACUMOS_MARIADB_PORT ACUMOS_MARIADB_USER_PASSWORD \
      ACUMOS_METRICBEAT_PORT"

    for comp in $comps; do
      start_service deploy/$comp-service.yaml
      start_deployment deploy/$comp-deployment.yaml
    done
  fi

  log "Wait for all elk-stack pods to be Running"
  if [[ "ACUMOS_DEPLOY_METRICBEAT" == "true" ]]; then
    apps="elasticsearch kibana logstash filebeat metricbeat"
  else
    aapps="elasticsearch kibana logstash filebeat"
  fi
  for app in $apps; do
    wait_running $app
  done
}

source $AIO_ROOT/acumos-env.sh
source elk-env.sh
source $AIO_ROOT/utils.sh
setup_prereqs
setup
