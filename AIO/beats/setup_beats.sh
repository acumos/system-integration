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
#    ELK stack core components deployed per setup_elk.sh, with acumos_env.sh and
#    elk_env.sh as updated by those scripts, for deployment options.
#
# Usage:
# For docker-based deployments, run this script on the AIO host.
# For k8s-based deployment, run this script on the AIO host or a workstation
# connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
# $ bash setup_beats.sh <AIO_ROOT> <beat>
#   AIO_ROOT: path to AIO folder where environment files are
#   beat: filebeat|metricbeat
#

function build_images() {
  trap 'fail' ERR
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
    sedi 's/{ELASTICSEARCH_HOST}:5601/{KIBANA_HOST}:${KIBANA_PORT}/' \
      ../platform-oam/metricbeat/config/metricbeat.yml
    cp -R ../platform-oam/metricbeat/config .
    cp -R ../platform-oam/metricbeat/module.d .
    docker build -t acumos-metricbeat .
  fi
  cd ..
}

clean_beat() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any existing docker based components for $beat"
    bash docker_compose.sh $AIO_ROOT $beat down
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

function metricbeat_configmap() {
  trap 'fail' ERR
  log "Create kubernetes configmap for metricbeat"
  if [[ $($k8s_cmd get configmap -n $ACUMOS_NAMESPACE metricbeat) ]]; then
    log "Delete existing metricbeat configmap"
    $k8s_cmd delete configmap -n $ACUMOS_NAMESPACE metricbeat
  fi
  # fix bug in metricbeat.yaml
  if [[ -d platform-oam ]]; then rm -rf platform-oam; fi
  git clone https://gerrit.acumos.org/r/platform-oam
  cp platform-oam/metricbeat/config/metricbeat.yml .
  sedi 's/{ELASTICSEARCH_HOST}:5601/{KIBANA_HOST}:${KIBANA_PORT}/' \
    metricbeat.yml
  $k8s_cmd create configmap -n $ACUMOS_NAMESPACE metricbeat \
    --from-file=metricbeat.yml
}

function setup_beat() {
  trap 'fail' ERR
  cd $AIO_ROOT/beats
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    build_images
    bash docker_compose.sh $AIO_ROOT $beat up -d --build --force-recreate
    wait_running $beat-service
  else
    log "Deploy the k8s based component $beat"
    if [[ "$beat" == "metricbeat" ]]; then metricbeat_configmap; fi
    mkdir -p deploy
    cp -r kubernetes/$beat-* deploy/.
    replace_env deploy
    start_service deploy/$beat-service.yaml
    start_deployment deploy/$beat-deployment.yaml
    wait_running $beat $ACUMOS_NAMESPACE
  fi
}

if [[ $# -lt 1 ]]; then
  cat <<'EOF'
Usage:
  For docker-based deployments, run this script on the AIO host.
  For k8s-based deployment, run this script on the AIO host or a workstation
  connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
  $ bash setup_beats.sh <AIO_ROOT> [beat]
    AIO_ROOT: path to AIO folder where environment files are
    beat: filebeat|metricbeat (optional: default is to deploy both)
EOF
  echo "All parameters not provided"
  exit 1
fi

WORK_DIR=$(pwd)
export AIO_ROOT=$1
source $AIO_ROOT/acumos_env.sh
source $AIO_ROOT/utils.sh
trap 'fail' ERR
cd $AIO_ROOT/beats
source beats_env.sh
if [[ "$2" == "" ]]; then beats="filebeat metricbeat"
else beats=$2
fi
for beat in $beats; do
  clean_beat
  setup_beat
done
cd $WORK_DIR
