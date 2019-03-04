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

if [[ "$K8S_DIST" == "openshift" ]]; then k8s_cmd=oc
else k8s_cmd=kubectl
fi

function fail() {
  set +x
  trap - ERR
  save_logs
  log "Debug logs are saved at /tmp/acumos/debug"
  if [[ -e ../acumos-env.sh ]]; then cd ..; fi
  source acumos-env.sh
  update_env DEPLOY_RESULT fail
  update_env FAIL_REASON "\"$1\""
  log "$1"
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

function wait_until_notfound() {
  trap 'fail' ERR
  cmd="$1"
  what="$2"
  log "Waiting until $what is missing from output of \"$cmd\""
  result=$($cmd)
  while [[ $(echo $result | grep -c "$what") -gt 0 ]]; do
    log "Waiting 10 seconds"
    sleep 10
    result=$($cmd)
  done
}

function wait_until_fail() {
  trap 'fail' ERR
  cmd="$1"
  log "Waiting for \"$cmd\" to fail"
  while $cmd ; do
    log "Command \"$cmd\" succeeded, waiting 10 seconds"
    sleep 10
  done
}

function wait_until_success() {
  trap 'fail' ERR
  cmd="$1"
  log "Waiting for \"$cmd\" to succeed"
  while ! $cmd ; do
    log "Command \"$cmd\" failed, waiting 10 seconds"
    sleep 10
  done
}

function stop_service() {
  trap 'fail' ERR
  if [[ -e $1 ]]; then
    app=$(grep "app: " -m1 $1 | sed 's/^.*app: //')
    if [[ $($k8s_cmd get svc -n $ACUMOS_NAMESPACE -l app=$app) ]]; then
      log "Stop service for $app"
      $k8s_cmd delete -f $1
      wait_until_notfound "$k8s_cmd get svc -n $ACUMOS_NAMESPACE" "^$app"
    else
      log "Service not found for $app"
    fi
  fi
}

function stop_deployment() {
  trap 'fail' ERR
  if [[ -e $1 ]]; then
    app=$(grep "app: " -m1 $1 | sed 's/^.*app: //')
    # Note any related PV and PVC are not deleted
    if [[ $($k8s_cmd get deployment -n $ACUMOS_NAMESPACE -l app=$app) ]]; then
      log "Stop deployment for $app"
      $k8s_cmd delete -f $1
      wait_until_notfound "$k8s_cmd get pods -n $ACUMOS_NAMESPACE" "^$app"
    else
      log "Deployment not found for $app"
    fi
  fi
}

function update_env() {
  # Reuse existing values if set
  if [[ "${!1}" == "" ]]; then
    export $1=$2
    log "Updating acumos-env.sh with \"export $1=$2\""
    sed -i -- "s~$1=.*~$1=$2~" $AIO_ROOT/acumos-env.sh
  fi
}

function replace_env() {
  trap 'fail' ERR
  log "Set variable values in k8s templates at $1"
  set +x
  vars=$(grep -Rho '<[^<.]*>' $1/* | sed 's/<//' | sed 's/>//' | sort | uniq)
  for f in $1/*.yaml; do
    for v in $vars ; do
      eval vv=\$$v
      sed -i -- "s~<$v>~$vv~g" $f
    done
  done
  set -x
}

function start_service() {
  trap 'fail' ERR
  name=$(grep "name: " -m1 $1 | sed 's/^.*name: //')
  log "Creating service $name"
  $k8s_cmd create -f $1
}

function start_deployment() {
  trap 'fail' ERR
  name=$(grep "name: " -m1 $1 | sed 's/^.*name: //')
  log "Creating deployment $name"
  $k8s_cmd create -f $1
}

function check_running() {
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    cs=$(sudo docker ps -a | awk "/$app/{print \$1}")
    status="Running"
    for c in $cs; do
      if [[ $(sudo docker ps -f id=$c | grep -c " Up ") -eq 0 ]]; then
        status="Not yet Up"
      fi
    done
  else
    status=$($k8s_cmd get pods -n $ACUMOS_NAMESPACE -l app=$app | awk '/-/ {print $3}')
  fi
  log "$app status is $status"
}

function wait_running() {
  trap 'fail' ERR
  app=$1
  log "Wait for $app to be running"
  t=1
  check_running
  while [[ "$status" != "Running" && $t -le 30 ]]; do
    ((t++))
    sleep 10
    check_running
  done
  if [[ $t -gt 30 ]]; then
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
}

function save_logs() {
  if [[ -e /tmp/acumos/debug ]]; then rm -rf /tmp/acumos/debug; fi
  mkdir -p /tmp/acumos/debug
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    if [[ $(which docker) ]]; then
      sudo docker ps -a | grep acumos | tee /tmp/acumos/debug/acumos-containers.log
      cs=$(sudo docker ps --format '{{.Names}}' | grep acumos)
      for c in $cs; do
        sudo bash -c "nohup docker ps -f name=$c | tee /tmp/acumos/debug/$c.log 1>/dev/null 2>&1 &" 1>/dev/null 2>&1
        sudo bash -c "nohup docker logs $c | tee -a /tmp/acumos/debug/$c.log 1>/dev/null 2>&1 &" 1>/dev/null 2>&1
      done
      sudo chown $USER:$USER -R /tmp/acumos
    fi
  else
    if [[ $(which kubectl) ]]; then
      kubectl describe pv > /tmp/acumos/debug/acumos-pv.log
      kubectl describe pvc -n $ACUMOS_NAMESPACE > /tmp/acumos/debug/acumos-pvc.log
      kubectl get svc -n $ACUMOS_NAMESPACE > /tmp/acumos/debug/acumos-svc.log
      kubectl describe svc -n $ACUMOS_NAMESPACE >>  /tmp/acumos/debug/acumos-svc.log
      kubectl get pods -n $ACUMOS_NAMESPACE > /tmp/acumos/debug/acumos-pods.log
      pods=$(kubectl get pods -n $ACUMOS_NAMESPACE -o json >/tmp/json)
      np=$(jq -r '.content | length' /tmp/json)
      i=0;
      while [[ $i -lt $np ]] ; do
        app=$(jq -r ".content[$i].metadata.labels.app" /tmp/json)
        kubectl describe pods -n $ACUMOS_NAMESPACE -l app=$app > /tmp/acumos/debug/$app.log
        nc=$(jq -r ".content[$i].spec.containers | length" /tmp/json)
        cs=$(jq -r ".content[$i].spec.containers" /tmp/json)
        j=0
        while [[ $j -lt $nc ]] ; do
          name=$(jq -r ".content[$i].spec.containers[$j].name" /tmp/json)
          echo "***** $name *****" >>  /tmp/acumos/debug/$app.log
          kubectl logs -n $ACUMOS_NAMESPACE -l app=$app -c $name >>  /tmp/acumos/debug/$app.log
        done
        ((i++))
      done
    fi
  fi
}

function find_user() {
  log "Find user $1"
  curl -s -o /tmp/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD \
    http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/user
  users=$(jq -r '.content | length' /tmp/json)
  i=0; userId=""
  # Disable trap as not finding the user will trigger ERR
  trap - ERR
  while [[ $i -lt $users && "$userId" == "" ]] ; do
    if [[ "$(jq -r ".content[$i].loginName" /tmp/json)" == "$1" ]]; then
      userId=$(jq -r ".content[$i].userId" /tmp/json)
    fi
    ((i++))
  done
  trap 'fail' ERR
}

function get_host_info() {
  if [[ $(bash --version | grep -c redhat-linux) -gt 0 ]]; then
    HOST_OS=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
    HOST_OS_VER=$(grep -m 1 'VERSION_ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
  elif [[ $(bash --version | grep -c pc-linux) -gt 0 ]]; then
    HOST_OS=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
    HOST_OS_VER=$(grep -m 1 'VERSION_ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
  elif [[ $(bash --version | grep -c apple) -gt 0 ]]; then
    HOST_OS=macos
  elif [[ $(bash --version | grep -c pc-msys) -gt 0 ]]; then
    HOST_OS=windows
    fail "Sorry, Windows is not supported."
  fi

  HOST_IP=$(/sbin/ip route get 8.8.8.8 | head -1 | sed 's/^.*src //' | awk '{print $1}')
}
