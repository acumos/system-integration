#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2019 Nordix Foundation.
# ===================================================================================
# This Acumos software file is distributed by Nordix Foundation
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
# What this is: Setup License Usage Manager Service in k8
# Prerequisites:
# - Kubernetes 1.13+ cluster
# Usage:
# - Intended to be called from oneclick_deploy.sh and other scripts in this repo
#

function prep_lum(){
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    if [[ $(kubectl create namespace $LUM_NAMESPACE) ]]; then
      log "Namespace $LUM_NAMESPACE created"
    fi
  fi
}

function cleanup_lum(){
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any existing docker based components for lum-service"
    cs=$(docker ps -a | awk '/lum/{print $1}')
    for c in $cs; do
      docker stop $c
      docker rm $c
    done
  else
    log "Remove LUM release"
    if [[ $(helm delete --purge $LUM_RELEASE_NAME) ]]; then
        log "Helm release $LUM_RELEASE_NAME deleted"
    fi
    if [[ $(kubectl delete pvc data-${LUM_RELEASE_NAME}-postgresql-0 -n ${LUM_NAMESPACE};) ]]; then
      log "pvc ${LUM_RELEASE_NAME}-postgresql-0 deleted"
    fi
    if [[ $(kubectl wait --for=delete pvc/data-${LUM_RELEASE_NAME}-postgresql-0 -n ${LUM_NAMESPACE} --timeout=60s;) ]]; then
      log "pvc ${LUM_RELEASE_NAME}-postgresql-0 deleted wait finished"
    fi
  fi

}

function setup_lum() {
  trap 'fail' ERR

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Deploy the docker based components for lum"
    bash docker_compose.sh up -d --build --force-recreate
    wait_running lum-server
  else
    # Get license-usage-manager repo here
    # point to path where cloned repo exists
    ## TODO change to master once merged in
    ## TODO use a helm registry -- would be better location
    rm -frd kubernetes/license-usage-manager
    git clone "https://gerrit.acumos.org/r/license-usage-manager" \
      kubernetes/license-usage-manager
    pathToLumHelmChart=./kubernetes/license-usage-manager/lum-helm
    create_acumos_registry_secret ${LUM_NAMESPACE}
    replace_env kubernetes/values.yaml
    # TEMP fix for external name - making it easier for portal to consume in acumos namespace
    replace_env kubernetes/external-name.yaml
    # ## copy in dependencies
    helm dependency build ${pathToLumHelmChart}
    helm install -f kubernetes/values.yaml --name $LUM_RELEASE_NAME  \
      --namespace ${LUM_NAMESPACE} --debug  ${pathToLumHelmChart}
    kubectl apply -f kubernetes/external-name.yaml
  fi
}

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]];
  then export AIO_ROOT="$(cd ..; pwd -P)";
fi
source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh
source lum_env.sh

action=$1
if [[ "$action" == "" ]]; then action=all; fi
# TODO default port is 8080 from helm chart -- remove hard coding here
LUM_EXTERNAL_NAME=$LUM_RELEASE_NAME-$LUM_CHART_NAME.$LUM_NAMESPACE.svc.cluster.local
LUM_EXTERNAL_PORT=8080

if [[ "$action" == "clean" || "$action" == "all" ]];
  then cleanup_lum $LUM_RELEASE_NAME
fi
if [[ "$action" == "prep" || "$action" == "all" ]];
  then prep_lum $LUM_RELEASE_NAME
fi
if [[ "$action" == "setup" || "$action" == "all" ]];
  then setup_lum  $LUM_RELEASE_NAME
fi

cd $WORK_DIR
