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
# What this is: script to setup Acumos Nexus repos
#
# Prerequisites:
# - acumos_env.sh script prepared through oneclick_deploy.sh or manually, to
#   set install options (e.g. docker/k8s)
# - If you want to specify environment values, set and export them prior
#   to running this script, e.g. by creating a script named mariadb_env.sh.
#   See setup_nexus_env.sh for the default values.
# - If you are deploying Nexus in standalone mode (i.e. running this script
#   directly), create a nexus_env.sh file including at least a value for
#     export ACUMOS_NEXUS_DOMAIN=<exernally-resolvable domain name>
#     export ACUMOS_NEXUS_HOST=<internally-resolvable domain name>
# - Additionally, for k8s:
#   - Available PVs with at least 10GiB disk and default storage class
#
# Usage:
# For docker-based deployments, run this script on the AIO host.
# For k8s-based deployment, run this script on the AIO host or a workstation
# connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
#
# $ bash setup_nexus.sh <clean|prep|setup|all>
#   clean|prep|setup|all: action to execute
#

function nexus_prep() {
  trap 'fail' ERR
  verify_ubuntu_or_centos
  create_namespace $ACUMOS_NEXUS_NAMESPACE
  if [[ "$ACUMOS_CREATE_PVS" == "true" && "$ACUMOS_PVC_TO_PV_BINDING" == "true" ]]; then
  bash $AIO_ROOT/../tools/setup_pv.sh all /mnt/$ACUMOS_NEXUS_NAMESPACE \
    $ACUMOS_NEXUS_DATA_PV_NAME $ACUMOS_NEXUS_DATA_PV_SIZE \
    "200:$ACUMOS_HOST_USER"
  fi
  if [[ "$K8S_DIST" == "openshift" ]]; then
    log "Workaround: Acumos AIO requires privilege to set PV permissions"
    oc adm policy add-scc-to-user anyuid -z default -n $ACUMOS_NEXUS_NAMESPACE
  fi
}

function nexus_clean() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any existing docker based components for nexus-service"
    bash docker_compose.sh down
  else
    log "Stop any existing k8s based components for nexus-service"
    if [[ ! -e deploy/nexus-service.yaml ]]; then
      mkdir -p deploy
      cp -r kubernetes/* deploy/.
      replace_env deploy
    fi
    stop_service deploy/nexus-service.yaml
    stop_deployment deploy/nexus-deployment.yaml
    log "Remove PVC for nexus-service"
    delete_pvc $ACUMOS_NEXUS_NAMESPACE $ACUMOS_NEXUS_DATA_PVC_NAME
  fi
}

function deploy_nexus_service() {
  trap 'fail' ERR
  log "Update the nexus-service template and deploy the service"
  mkdir -p deploy
  cp -r kubernetes/nexus-service.yaml deploy/.
  # Use dynamically assigned nodeports if port values are the default for docker
  if [[ "$ACUMOS_NEXUS_API_PORT" == "8081" ]]; then
    ACUMOS_NEXUS_API_PORT=
  fi
  if [[ "$ACUMOS_DOCKER_MODEL_PORT" == "8082" ]]; then
    ACUMOS_DOCKER_MODEL_PORT=
  fi
  replace_env deploy/nexus-service.yaml
  start_service deploy/nexus-service.yaml
  ACUMOS_NEXUS_API_PORT=$(kubectl get services -n $ACUMOS_NEXUS_NAMESPACE nexus-service -o json | jq -r '.spec.ports[0].nodePort')
  update_nexus_env ACUMOS_NEXUS_API_PORT $ACUMOS_NEXUS_API_PORT force
  ACUMOS_DOCKER_MODEL_PORT=$(kubectl get services -n $ACUMOS_NEXUS_NAMESPACE nexus-service -o json | jq -r '.spec.ports[1].nodePort')
  update_nexus_env ACUMOS_DOCKER_MODEL_PORT $ACUMOS_DOCKER_MODEL_PORT force
}

function nexus_setup() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    # If not set explictly, the default value will be for k8s based deployment...
    if [[ "$ACUMOS_NEXUS_HOST" == "$ACUMOS_INTERNAL_NEXUS_HOST" ]]; then
      update_nexus_env ACUMOS_NEXUS_HOST $ACUMOS_DOMAIN force
      update_nexus_env ACUMOS_DOCKER_REGISTRY_HOST $ACUMOS_DOMAIN force
    fi
    bash docker_compose.sh up -d --build --force-recreate
    wait_running nexus-service
  else
    log "Setup the nexus-data PVC"
    setup_pvc $ACUMOS_NEXUS_NAMESPACE $ACUMOS_NEXUS_DATA_PVC_NAME \
      $ACUMOS_NEXUS_DATA_PV_NAME $ACUMOS_NEXUS_DATA_PV_SIZE \
      $ACUMOS_NEXUS_DATA_PV_CLASSNAME

    if [[ "$(kubectl get service -n $ACUMOS_NEXUS_NAMESPACE nexus-service)" == "" ]]; then
      deploy_nexus_service
    fi

    log "Update the nexus deployment template and deploy it"
    mkdir -p deploy
    cp -r kubernetes/nexus-deployment.yaml deploy/.
    replace_env deploy/nexus-deployment.yaml
    start_deployment deploy/nexus-deployment.yaml
    wait_running nexus $ACUMOS_NEXUS_NAMESPACE
  fi

  # Add -m 10 since for some reason curl seems to hang waiting for a response
  cmd="curl -v -m 10 \
    -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD \
    http://$ACUMOS_NEXUS_DOMAIN:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script"
  local i=0
  while [[ ! $($cmd) ]]; do
    log "Nexus API is not ready... waiting 10 seconds"
    sleep 10
    i=$((i+10))
    if [[  $i -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      fail "Nexus API failed to respond"
    fi
  done
}

if [[ $# -lt 1 ]]; then
  cat <<'EOF'
 Usage:
 For docker-based deployments, run this script on the AIO host.
 For k8s-based deployment, run this script on the AIO host or a workstation
 connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)

 $ bash setup_nexus.sh <clean|prep|setup|all> <nexus_host>
   clean|prep|setup|all: action to execute
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

if [[ -e nexus_env.sh ]]; then
  log "Using prepared nexus_env.sh for customized environment values"
  source nexus_env.sh
fi

source setup_nexus_env.sh
cp nexus_env.sh $AIO_ROOT/.
action=$1
if [[ "$action" == "clean" || "$action" == "all" ]]; then nexus_clean; fi
if [[ "$action" == "prep" || "$action" == "all" ]]; then nexus_prep; fi
if [[ "$action" == "setup" || "$action" == "all" ]]; then nexus_setup; fi
cd $WORK_DIR
