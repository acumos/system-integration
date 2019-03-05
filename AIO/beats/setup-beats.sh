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
# What this is: setup; script for Filebeat or Metricbeat under docker or k8s
#
# Prerequisites:
# - Acumos platform core components installed per oneclick_deploy.sh, and
#    ELK stack core components deployed per setup-elk.sh, with acumos-env.sh and
#    elk-env.sh as updated by those scripts, for deployment options.
#
# Usage: on the AIO host where Acumos is being deployed
# $ bash setup-beats.sh <beat> <namespace>
#   beat: filebeat|metricbeat
#   namespace: ACUMOS_NAMESPACE (needed for logs PV name)
#

# First define utils that will overridden below
source ../utils.sh

function fail() {
  set +x
  trap - ERR
  reason="$1"
  if [[ "$1" == "" ]]; then reason="unknown"; fi
  sed -i -- 's/DEPLOY_RESULT=.*/DEPLOY_RESULT=fail/' elk-env.sh
  sed -i -- "s/FAIL_REASON=.*~FAIL_REASON=$reason~" elk-env.sh
  log "$reason"
  exit 1
}

function build_images() {
  log "Prepare $beat stack component image"
  if [[ -d platform-oam ]]; then rm -rf platform-oam; fi
  git clone https://gerrit.acumos.org/r/platform-oam

  if [[ "$beat" == "filebeat" ]]; then
    log "Building local acumos-filebeat image"
    # Per https://www.elastic.co/guide/en/beats/filebeat/current/running-on-docker.html
    cd filebeat
    cp -R ../platform-oam/filebeat/config .
    docker build -t acumos-filebeat .
  else
    log "Building local acumos-metricbeat image"
    cd metricbeat
    # fix bug in metricbeat.yaml
    sed -i -- 's/{ELASTICSEARCH_HOST}:5601/{KIBANA_HOST}:${KIBANA_PORT}/' \
      ../platform-oam/metricbeat/config/metricbeat.yml
    cp -R ../platform-oam/metricbeat/config .
    cp -R ../platform-oam/metricbeat/module.d .
    docker build -t acumos-metricbeat .
  fi
  cd ..
}

clean() {
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any existing docker based components for $beat"
    source docker-compose.sh $beat down
  else
    log "Stop any existing k8s based components for $beat"
    if [[ ! -e deploy/$beat-service.yaml ]]; then
      mkdir -p deploy
      cp -r kubernetes/$beat-* deploy/.
      replace_env deploy
    fi
    stop_service deploy/$beat-service.yaml
    stop_deployment deploy/$beat-deployment.yaml
  fi
}

function setup() {
  clean
  build_images

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    source docker-compose.sh $beat up -d --build --force-recreate
  else
    log "Deploy the k8s based component $beat"
    mkdir -p deploy
    cp -r kubernetes/$beat-* deploy/.
    replace_env deploy
    start_service deploy/$beat-service.yaml
    start_deployment deploy/$beat-deployment.yaml
  fi

  log "Wait for $beat pod to be Running"
  wait_running $beat
}

source ../elk-stack/elk-env.sh
source beats-env.sh
beat=$1
ACUMOS_NAMESPACE=$2
setup
