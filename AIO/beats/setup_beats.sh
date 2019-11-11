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
# $ bash setup_beats.sh <beat>
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
    bash docker_compose.sh $beat down
  else
    log "Stop any existing k8s based components for $beat"
    if [[ ! -e deploy/$beat-service.yaml ]]; then
      mkdir -p deploy
      cp -r kubernetes/$beat-* deploy/.
      replace_env deploy
    fi
    stop_service deploy/$beat-service.yaml
    stop_deployment deploy/$beat-deployment.yaml
    if [[ "$beat" == "metricbeat" ]]; then
      cfgs="metricbeat-config metricbeat-modules"
      for cfg in $cfgs; do
        if [[ $(kubectl delete configmap -n $ACUMOS_NAMESPACE $cfg) ]]; then
          log "configmap $cfg deleted"
        fi
      done
    fi
  fi
  cleanup_snapshot_images
}

function metricbeat_configmap() {
  trap 'fail' ERR
  log "Create kubernetes configmaps for metricbeat"
  # fix bug in metricbeat.yaml
  if [[ -d platform-oam ]]; then rm -rf platform-oam; fi
  git clone https://gerrit.acumos.org/r/platform-oam
  cp platform-oam/metricbeat/config/metricbeat.yml .
  cp -r platform-oam/metricbeat/module.d .
  mv module.d modules.d
  sedi 's/{ELASTICSEARCH_HOST}:5601/{KIBANA_HOST}:${KIBANA_PORT}/' \
    metricbeat.yml
  kubectl create configmap -n $ACUMOS_NAMESPACE metricbeat-config \
    --from-file=metricbeat.yml
  kubectl create configmap -n $ACUMOS_NAMESPACE metricbeat-modules \
    --from-file=modules.d
}

function setup_beat() {
  trap 'fail' ERR
  cd $AIO_ROOT/beats
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    build_images
    bash docker_compose.sh $beat up -d --build --force-recreate
    wait_running $beat-service
  else
    log "Deploy the k8s based component $beat"
    if [[ "$beat" == "metricbeat" ]]; then metricbeat_configmap; fi
    mkdir -p deploy
    cp -r kubernetes/$beat-* deploy/.
    # Per  https://github.com/elastic/beats/issues/8253
    if [[ "$beat" == "filebeat" && "$K8S_DIST" == "openshift" ]]; then
      sedi 's/<ACUMOS_PRIVILEGED_ENABLE>/true/' deploy/filebeat-deployment.yaml
    fi
    replace_env deploy
    get_host_ip_from_etc_hosts $ACUMOS_ELK_DOMAIN
    if [[ "$HOST_IP" != "" ]]; then
      patch_template_with_host_alias deploy/$beat-deployment.yaml $ACUMOS_ELK_DOMAIN $HOST_IP
    fi

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
  $ bash setup_beats.sh <beat>
    beat: filebeat|metricbeat
EOF
  echo "All parameters not provided"
  exit 1
fi

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ..; pwd -P)"; fi
source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh
source beats_env.sh
beat=$1
clean_beat
setup_beat
cd $WORK_DIR
