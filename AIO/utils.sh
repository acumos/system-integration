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
# - acumos_env.sh customized for this platform, as by oneclick_deploy.sh
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
  cd $AIO_ROOT
  reason="$1"
  if [[ "$1" == "" ]]; then reason="unknown failure at $fname $fline"; fi
  if [[ -e $AIO_ROOT/acumos_env.sh ]]; then
    sedi "s/DEPLOY_RESULT=.*/DEPLOY_RESULT=fail/" acumos_env.sh
    sedi "s/FAIL_REASON=.*/FAIL_REASON=\"$reason\"/" acumos_env.sh
  fi
  log "$reason"
  exit 1
}

function log() {
  set +x
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  echo; echo "$fname:$fline ($(date)) $1"
  set -x
}

set_k8s_env() {
  # Variations on objects between generic and openshift k8s
  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    if [[ "$K8S_DIST" == "openshift" ]]; then
      export k8s_cmd=oc
      export k8s_nstype=project
    else
      export k8s_cmd=kubectl
      export k8s_nstype=namespace
    fi
  fi
}

function sedi () {
    sed --version >/dev/null 2>&1 && sed -i -- "$@" || sed -i "" "$@"
}

function docker_login() {
  wait_until_success 30 \
    "docker login $1 -u $ACUMOS_PROJECT_NEXUS_USERNAME -p $ACUMOS_PROJECT_NEXUS_PASSWORD"
}

function create_acumos_registry_secret() {
  local namespace=$1
  log "Login to LF Nexus Docker repos, for Acumos project images"
  docker_login https://nexus3.acumos.org:10004
  docker_login https://nexus3.acumos.org:10003
  docker_login https://nexus3.acumos.org:10002

  if [[ $($k8s_cmd get secret -n $namespace acumos-registry) ]]; then
    log "Deleting k8s secret acumos-registry, prior to recreating it"
    $k8s_cmd delete secret -n $namespace acumos-registry
  fi

  log "Create k8s secret for image pulling from docker"
  get_host_info
  if [[ "$HOST_OS" == "macos" ]]; then
    b64=$(cat $HOME/.docker/config.json | base64)
  else
    b64=$(cat $HOME/.docker/config.json | base64 -w 0)
  fi
  cat <<EOF >acumos-registry.yaml
apiVersion: v1
kind: Secret
metadata:
  name: acumos-registry
  namespace: $namespace
data:
  .dockerconfigjson: $b64
type: kubernetes.io/dockerconfigjson
EOF

  $k8s_cmd create -f acumos-registry.yaml
}

function create_namespace() {
  local namespace=$1
  if [[ ! $($k8s_cmd get $k8s_nstype $namespace) ]]; then
    log "Creating $k8s_nstype $namespace"
    if [[ "$K8S_DIST" == "openshift" ]]; then
      oc new-project $namespace
    else
      kubectl create namespace $namespace
    fi
    wait_until_success 6 "$k8s_cmd get $k8s_nstype $namespace"
  else
    log "$k8s_nstype $namespace already exists"
  fi
}

function delete_namespace() {
  trap 'fail' ERR
  if [[ "$K8S_DIST" == "openshift" ]]; then
    if [[ $(oc get project $1) ]]; then
      oc delete project $1
      while oc get project $1 ; do
        log "Waiting for project $1 to be deleted"
        sleep 10
      done
    fi
  elif [[ $(kubectl get namespace $1) ]]; then
    kubectl delete namespace $1
    while kubectl get namespace $1 ; do
      log "Waiting for namespace $1 to be deleted"
      sleep 10
    done
  fi
}

function setup_pvc() {
  local pvc=$1
  local namespace=$2
  local size=$3
  local name=pvc-${namespace}-$pvc
  trap 'fail' ERR

  if [[ "$($k8s_cmd get pvc -n $namespace pvc-$namespace-$pvc)" == "" ]]; then
    log "Creating PVC $name"
    # Add volumeName: to ensure the PVC selects a specific volume as data
    # may be pre-configured there
    tmp=/tmp/$(uuidgen)
    cat <<EOF >$tmp
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: $name
spec:
  storageClassName: $namespace
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: $size
  volumeName: "pv-$namespace-$pvc"
EOF

    $k8s_cmd create -n $namespace -f $tmp
    $k8s_cmd get pvc -n $namespace $name
    rm $tmp
  else
    log "$namespace PVC pvc-$namespace-$pvc alrteady exists"
  fi
}

function delete_pvc() {
  trap 'fail' ERR
  local pvc=$1
  local namespace=$2
  local name=pvc-${namespace}-$pvc
  if [[ "$($k8s_cmd get pvc -n $namespace $name)" != "" ]]; then
    $k8s_cmd delete pvc -n $namespace $name
    while $k8s_cmd get pvc -n $namespace $name ; do
     log "Waiting for $namespace PVC $name to be deleted"
      sleep 10
    done
  fi
}

function reset_pv() {
  log "Remove any existing PV data for $1"
  delete_pv $1 $2
  log "Setup the $1 PV"
  setup_pv $1 $2 $3 $4
}

function setup_pv() {
  trap 'fail' ERR
  local pv=$1
  local namespace=$2
  local size=$3
  local owner=$4
  local path=/mnt/$namespace/$1
  local name=pv-${namespace}-$pv
  if [[ ! -e /mnt/$namespace ]]; then
    log "Creating /mnt/$namespace as PV root folder"
    sudo mkdir /mnt/$namespace
    sudo chown $ACUMOS_HOST_USER:$ACUMOS_HOST_USER /mnt/$namespace
  fi
  if [[ ! -e $path ]]; then
    sudo mkdir -p $path
    # TODO: remove/relax this workaround
    # Required for various components to be able to write to the PVs
    sudo chmod 777 $path
    sudo chown $owner $path
  fi

  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    # Per https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/
    log "Creating kubernetes PV $name"
    tmp=/tmp/$(uuidgen)
    cat <<EOF >$tmp
kind: PersistentVolume
apiVersion: v1
metadata:
  name: $name
spec:
  storageClassName: $namespace
  capacity:
    storage: $size
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  hostPath:
    path: "$path"
EOF

    $k8s_cmd create -f $tmp
    $k8s_cmd get pv $name
  fi
}

function delete_pv() {
  trap 'fail' ERR
  local pv=$1
  local namespace=$2
  local path=/mnt/$namespace/$1
  local name=pv-${namespace}-$pv
  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    if [[ "$($k8s_cmd get pv $name)" != "" ]]; then
      $k8s_cmd delete pv $name
      while $k8s_cmd get pv $name ; do
       log "Waiting for PV $name to be deleted"
        sleep 10
      done
    fi
  fi
  if [[ -e $path ]]; then
    log "Deleting host folder $path"
    sudo rm -rf $path
  fi
}

function wait_until_notfound() {
  trap 'fail' ERR
  local cmd="$1"
  local what="$2"
  log "Waiting until $what is missing from output of \"$cmd\""
  local i=0
  local max=30
  local result=$($cmd)
  while [[ $(echo $result | grep -c "$what") -gt 0 ]]; do
    log "Waiting 10 seconds"
    i=$((i+1))
    if [[ $i -eq $max ]]; then
      fail "Request did not succeed in $max tries"
    fi
    sleep 10
    result=$($cmd)
  done
}

function wait_until_success() {
  trap 'fail' ERR
  local max=$1
  local cmd="$2"
  log "Waiting for \"$cmd\" to succeed"
  local i=0
  while ! $cmd ; do
    log "Command \"$cmd\" failed, waiting 10 seconds"
    sleep 10
    i=$((i+1))
    if [[ $i -eq $max ]]; then
      fail "Request did not succeed in $max tries"
    fi
  done
}

function check_running() {
  # Returns status
  local app=$1
  local namespace=$2
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    cs=$(docker ps -a | awk "/$app/{print \$1}")
    status="Running"
    for c in $cs; do
      if [[ $(docker ps -f id=$c | grep -c " Up ") -eq 0 ]]; then
        status="Not yet Up"
      fi
    done
  else
    # TODO: handle case with multiple pods per app
    status=$($k8s_cmd get pods -n $namespace -l app=$app -o json | jq -r '.items[0].status.phase')
  fi
  log "$app status is $status"
}

function inspect_pods_for_app() {
  local app=$1
  local namespace=$2
  local pods=$($k8s_cmd get pods -n $namespace -l app=$app -o json)
  local np=$(echo $pods | jq '.items | length')
  local i=0
  local pod
  while [[ $i -lt $np ]]; do
    pod=$(echo $pods | jq -r ".items[$i].metadata.name")
    $k8s_cmd get pods -n $namespace $pod
    kubectl describe pods -n $namespace $pod
    nc=$(echo $pods | jq ".items[$i].spec.containers | length")
    local j=0
    local name
    while [[ $j -lt $nc ]] ; do
      name=$(echo $pods | jq ".items[$i].spec.containers[$j].name")
      kubectl logs -n $ACUMOS_NAMESPACE -l app=$app -c $name
      j=$((j+1))
    done
    kubectl logs -n $namespace $pod
    i=$((i+1))
  done
}

function wait_running() {
  trap 'fail' ERR
  local app=$1
  local namespace=$2
  log "Wait for $app to be running"
  t=1
  check_running $app $namespace
  while [[ "$status" != "Running" && $t -le 30 ]]; do
    t=$((t+1))
    sleep 10
    check_running $app $namespace
  done
  if [[ $t -gt 30 ]]; then
    if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
      cs=$(docker ps -a | awk "/$app/{print \$1}")
      for c in $cs; do
        if [[ $(docker ps -f id=$c | grep -c " Up ") -eq 0 ]]; then
          docker ps -f id=$c
          docker logs $c
        fi
      done
    else
      inspect_pods_for_app $app $namespace
    fi
    fail "$1 failed to become Running"
  fi
}

function start_service() {
  trap 'fail' ERR
  local name=$(grep "name: " -m1 $1 | sed 's/^.*name: //')
  log "Creating service $name"
  $k8s_cmd create -f $1
}

function stop_service() {
  trap 'fail' ERR
  local app
  if [[ -e $1 ]]; then
    app=$(grep "app: " -m1 $1 | sed 's/^.*app: //')
    if [[ $($k8s_cmd get svc -n $ACUMOS_NAMESPACE -l app=$app) ]]; then
      log "Stop service for $app"
      $k8s_cmd delete service -n $ACUMOS_NAMESPACE $app-service
      wait_until_notfound "$k8s_cmd get svc -n $ACUMOS_NAMESPACE" $app
    else
      log "Service not found for $app"
    fi
  fi
}

function start_deployment() {
  trap 'fail' ERR
  local name=$(grep "name: " -m1 $1 | sed 's/^.*name: //')
  log "Creating deployment $name"
  $k8s_cmd create -f $1
}

function stop_deployment() {
  trap 'fail' ERR
  local app
  if [[ -e $1 ]]; then
    app=$(grep "app: " -m1 $1 | sed 's/^.*app: //')
    # Note any related PV and PVC are not deleted
    if [[ $($k8s_cmd get deployment -n $ACUMOS_NAMESPACE -l app=$app) ]]; then
      log "Stop deployment for $app"
      $k8s_cmd delete deployment -n $ACUMOS_NAMESPACE $app
      wait_until_notfound "$k8s_cmd get pods -n $ACUMOS_NAMESPACE" $app
    else
      log "Deployment not found for $app"
    fi
  fi
}

function wait_completed() {
  local job=$1
  local status
  log "Waiting for job $job to be Completed"
  status=$($k8s_cmd get job -n $ACUMOS_NAMESPACE -o json $job | jq -r '.status.conditions[0].type')
  while [[ "$status" != "Complete" ]]; do
    $k8s_cmd get pods -n $ACUMOS_NAMESPACE
    log "Job $job status is $status ... waiting 10 seconds"
    sleep 10
    status=$($k8s_cmd get job -n $ACUMOS_NAMESPACE -o json $job | jq -r '.status.conditions[0].type')
  done
}

function stop_job() {
  trap 'fail' ERR
  local job=$1
  if [[ $($k8s_cmd get job -n $ACUMOS_NAMESPACE $job) ]]; then
    log "Stop job $job"
    $k8s_cmd delete job -n $ACUMOS_NAMESPACE $job
    wait_until_notfound "$k8s_cmd get pods -n $ACUMOS_NAMESPACE" $job
  else
    log "Job $job not found"
  fi
}

function update_env() {
  # Reuse existing values if set
  if [[ "${!1}" == "" || "$3" == "force" ]]; then
    export $1=$2
    log "Updating acumos_env.sh with \"export $1=$2\""
    sedi "s~$1=.*~$1=$2~" $AIO_ROOT/acumos_env.sh
  fi
}

function replace_env() {
  trap 'fail' ERR
  local files; local vars; local v; local vv
  log "Set variable values in k8s templates at $1"
  set +x
  if [[ -f $1 ]]; then files="$1";
  else files="$1/*.yaml"; fi
  vars=$(grep -Rho '<[^<.]*>' $files | sed 's/<//' | sed 's/>//' | sort | uniq)
  for f in $files; do
    echo "Replacing env variables in $f"
    for v in $vars ; do
      eval vv=\$$v
      sedi "s~<$v>~$vv~g" $f
    done
  done
  set -x
}

function save_logs() {
  set +x
  local logs; local pods; local np; local cs; local nc; local i; local j; local name;
  log "Saving debug logs"
  logs=/home/$USER/acumos/logs
  if [[ $(mkdir -p $logs) ]]; then
    if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
      if [[ $(which docker) ]]; then
        docker ps -a | grep acumos | tee $logs/acumos-containers.log
        cs=$(docker ps --format '{{.Names}}' | grep acumos)
        for c in $cs; do
          # running the command under bash and redirecting prevents the logs
          # from also being output to the screen
          bash -c "nohup docker ps -f name=$c | tee $logs/$c.log 1>/dev/null 2>&1 &" 1>/dev/null 2>&1
          bash -c "nohup docker logs $c | tee -a $logs/$c.log 1>/dev/null 2>&1 &" 1>/dev/null 2>&1
        done
      fi
    else
      kubectl describe pv > $logs/acumos-pv.log
      kubectl describe pvc -n $ACUMOS_NAMESPACE > $logs/acumos-pvc.log
      kubectl get svc -n $ACUMOS_NAMESPACE > $logs/acumos-svc.log
      kubectl describe svc -n $ACUMOS_NAMESPACE >>  $logs/acumos-svc.log
      kubectl get pods -n $ACUMOS_NAMESPACE > $logs/acumos-pods.log
      local tmp="/tmp/$(uuidgen)"
      pods=$(kubectl get pods -n $ACUMOS_NAMESPACE -o json >$tmp)
      np=$(jq -r '.content | length' $tmp)
      i=0;
      while [[ $i -lt $np ]] ; do
        app=$(jq -r ".content[$i].metadata.labels.app" $tmp)
        kubectl describe pods -n $ACUMOS_NAMESPACE -l app=$app > $logs/$app.log
        nc=$(jq -r ".content[$i].spec.containers | length" $tmp)
        cs=$(jq -r ".content[$i].spec.containers" $tmp)
        j=0
        while [[ $j -lt $nc ]] ; do
          name=$(jq -r ".content[$i].spec.containers[$j].name" $tmp)
          echo "***** $name *****" >>  $logs/$app.log
          kubectl logs -n $ACUMOS_NAMESPACE -l app=$app -c $name >>  $logs/$app.log
        done
        i=$((i+1))
      done
      rm $tmp
    fi
  fi
}

function find_user() {
  log "Find user $1"
  local tmp="/tmp/$(uuidgen)"
  curl -s -o $tmp -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD \
    -k https://$ACUMOS_HOST:$ACUMOS_KONG_PROXY_SSL_PORT/ccds/user
  users=$(jq -r '.content | length' $tmp)
  i=0; userId=""
  # Disable trap as not finding the user will trigger ERR
  trap - ERR
  while [[ $i -lt $users && "$userId" == "" ]] ; do
    if [[ "$(jq -r ".content[$i].loginName" $tmp)" == "$1" ]]; then
      userId=$(jq -r ".content[$i].userId" $tmp)
    fi
    i=$((i+1))
  done
  rm $tmp
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
}

function get_host_ip() {
  log "Determining host IP address for $1"
  if [[ $(host $1 | grep -c 'not found') -eq 0 ]]; then
    HOST_IP=$(host $1 | head -1 | cut -d ' ' -f 4)
  elif [[ $(grep -c -E   " $1( |$)" /etc/hosts) -gt 0 ]]; then
    HOST_IP=$(grep -E "$1( |$)" /etc/hosts | cut -d ' ' -f 1)
  else
    log "Please ensure $1 is resolvable thru DNS or hosts file"
    fail "IP address of $1 cannot be determined."
  fi
}
