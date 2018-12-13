#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
# ===================================================================================
# This Acumos software file is distributed by AT&T and Tech Mahindra
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
# What this is: Utility functions for the AIO toolset. Defines functions that
# are used in the various AIO scripts
#
# Prerequisites:
# - Ubuntu Xenial or Centos 7 server
# - acumos-env.sh customized for this platform, as by oneclick_deploy.sh
#
# Usage: intended to be called from oneclick_deploy.sh and other scripts via
# - source $AIO_ROOT/utils.sh
#

set -x
dist=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
if [[ "$K8S_DIST" == "openshift" ]]; then k8s_cmd=oc
else k8s_cmd=kubectl
fi

function fail() {
  log "$1"
  save_logs
  log "Debug logs are saved at /tmp/acumos"
  exit 1
}

function log() {
  set +x
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  echo; echo "$fname:$fline ($(date)) $1"
  set -x
}

function wait_dpkg() {
  # TODO: workaround for "E: Could not get lock /var/lib/dpkg/lock - open (11: Resource temporarily unavailable)"
  echo; echo "waiting for dpkg to be unlocked"
  while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
    sleep 1
  done
}

function stop_service() {
  if [[ -e $1 ]]; then
    app=$(grep "app: " -m1 $1 | cut -d ":" -f 2)
    log "Stop $app"
    $k8s_cmd delete -f $1
  fi
}

function stop_deployment() {
  if [[ -e $1 ]]; then
    app=$(grep "app: " -m1 $1 | cut -d ":" -f 2)
    # Note any related PV and PVC are not deleted
    log "Stop $app"
    $k8s_cmd delete -f $1
    pod=$($k8s_cmd get pods -n $ACUMOS_NAMESPACE -l app=$app | awk '/-/{print $1}')
    while [[ "$pod" != "" ]]; do
      log "Waiting 10 seconds for pod $pod to be removed"
      sleep 10
      pod=$($k8s_cmd get pods -n $ACUMOS_NAMESPACE -l app=$app | awk '/-/{print $1}')
    done
  fi
}

function replace_env() {
  log "Set variable values in k8s templates at $1"
  for f in $1/*.yaml; do
    for v in $2 ; do
      eval vv=\$$v
      sed -i -- "s~<$v>~$vv~g" $f
    done
  done
}

function start_service() {
  app=$(grep "name: " -m1 $1 | cut -d ":" -f 2)
  log "Creating service $name"
  $k8s_cmd create -f $1
}

function start_deployment() {
  app=$(grep "name: " -m1 $1 | cut -d ":" -f 2)
  log "Creating deployment $name"
  $k8s_cmd create -f $1
}

function wait_running() {
  app=$1
  log "Wait for $app to be running"
  tries=0
  status=""
  while [[ "$status" != "Running" ]]; do
    if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
      cs=$(sudo docker ps -a | awk "/$app/{print \$1}")
      status="Running"
      for c in $cs; do
        if [[ $(sudo docker ps -f id=$c | grep -c " Up ") -eq 0 ]]; then
          status=""
        fi
      done
    else
      status=$($k8s_cmd get pods -n $ACUMOS_NAMESPACE -l app=$app | awk '/-/ {print $3}')
    fi
    if [[ "$status" != "Running" ]]; then
      if [[ $tries -eq 10 ]]; then
        if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
          cs=$(sudo docker ps -a | awk "/$app/{print \$1}")
          for c in $cs; do
            if [[ $(sudo docker ps -f id=$c | grep -c " Up ") -eq 0 ]]; then
              sudo docker ps -f id=$c
              sudo docker logs $c
            fi
          done
        else
          pod=$($k8s_cmd get pods -n $ACUMOS_NAMESPACE -l app=$app | awk '/-/ {print $1}')
          kubectl describe pods -n $ACUMOS_NAMESPACE $pod
          kubectl logs -n $ACUMOS_NAMESPACE $pod
        fi
        fail "$1 failed to become Running"
      fi
      ((tries++))
      log "$1 status is $status. Waiting 10 seconds"
      sleep 10
    fi
  done
  log "$1 status is $status"
}

function save_logs() {
  mkdir -p /tmp/acumos
  rm /tmp/acumos/*
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    sudo docker ps -a | grep acumos > /tmp/acumos/acumos-containers.log
    cs=$(sudo docker ps --format '{{.Names}}' | grep acumos)
    for c in $cs; do
      sudo docker ps -f name=$c > /tmp/acumos/$c.log
      sudo docker logs $c >>  /tmp/acumos/$c.log
    done
  else
    kubectl describe pv > /tmp/acumos/acumos-pv.log
    kubectl describe pvc -n $ACUMOS_NAMESPACE > /tmp/acumos/acumos-pvc.log
    kubectl get svc -n $ACUMOS_NAMESPACE > /tmp/acumos/acumos-svc.log
    kubectl describe svc -n $ACUMOS_NAMESPACE >>  /tmp/acumos/acumos-svc.log
    kubectl get pods -n $ACUMOS_NAMESPACE > /tmp/acumos/acumos-pods.log
    pods=$(kubectl get pods -n $ACUMOS_NAMESPACE -o json)
    np=$(jq -r '.content | length' /tmp/json)
    i=0;
    while [[ $i -lt $np ]] ; do
      app=$(jq -r ".content[$i].metadata.labels.app" /tmp/json)
      kubectl describe pods -n $ACUMOS_NAMESPACE -l app=$app > /tmp/acumos/$app.log
      nc=$(jq -r ".content[$i].spec.containers | length" /tmp/json)
      cs=$(jq -r ".content[$i].spec.containers" /tmp/json)
      j=0
      while [[ $j -lt $nc ]] ; do
        name=$(jq -r ".content[$i].spec.containers[$j].name" /tmp/json)
        echo "***** $name *****" >>  /tmp/acumos/$app.log
        kubectl logs -n $ACUMOS_NAMESPACE -l app=$app -c $name >>  /tmp/acumos/$app.log
      done
      ((i++))
    done
  fi
}
