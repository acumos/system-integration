#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2019 AT&T Intellectual Property. All rights reserved.
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
# What this is: script for deploying a user-specific NiFi service
#
# Prerequisites:
# - Acumos AIO platform deployed
# - Access to system-integration clone, as updated during the install process
#
# Usage: see below

set -x
if [[ $# -lt 1 ]]; then
  cat <<'EOF'
Usage:
  For k8s-based deployments run this script on the AIO install host or on
  a workstation configured for remote use of kubectl/oc, e.g. as setup by
  system-integration/tools/setup_kubectl.sh or
  system-integration/tools/setup_openshift_client.sh

  $ bash deploy_nifi_user.sh <user>
    user: username

    If redeployment is successful, the script will tail the user service
    component's logs. Hit ctrl-c to stop tailing the logs.
EOF
  echo "All parameters not provided"
  exit 1
fi

function tail_logs() {
  namespace=$1
  app=$2
  pod=$(kubectl get pods -n $namespace -l app=$app | awk "/$app-/{print \$1}")
  kubectl logs -f -n $namespace $pod
}

function deploy_nifi_user() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    fail "Deployment under docker is not supported"
  else
    if [[ ! -e deploy ]]; then mkdir deploy; fi
    cp kubernetes/user/nifi-user-*.yaml deploy/.
    export NIFI_USER=$NIFI_USER
    app="nifi-$NIFI_USER"
    replace_env deploy
    if $k8s_cmd get service -n $ACUMOS_NAMESPACE $app-service; then
      $k8s_cmd delete service -n $ACUMOS_NAMESPACE $app-service
      wait_until_notfound "$k8s_cmd get svc -n $ACUMOS_NAMESPACE" $app-service
    fi
    $k8s_cmd create -f deploy/nifi-user-service.yaml
    if $k8s_cmd get deployment -n $ACUMOS_NAMESPACE $app; then
      $k8s_cmd delete deployment -n $ACUMOS_NAMESPACE $app
      wait_until_notfound "$k8s_cmd get pods -n $ACUMOS_NAMESPACE" $app
    fi
    $k8s_cmd create -f deploy/nifi-user-deployment.yaml
    while [[ "$($k8s_cmd get pods -n $ACUMOS_NAMESPACE -l app=$app -o json | jq -r '.items[0].status.phase')" != "Running" ]]; do
      log "Waiting for $app pod to be Running"
    done
  fi
  tail_logs $ACUMOS_NAMESPACE $app
}

NIFI_USER=$1
WORK_DIR=$(pwd)
cd $(dirname "$0")
source acumos_env.sh
export AIO_ROOT=$(pwd)
source utils.sh

function fail() {
  log "$1"
  cd $WORK_DIR
  exit 1
}

deploy_nifi_user
cd $WORK_DIR
