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

function cleanup_lum_k8(){
    trap 'fail' ERR
    local releaseName=$1;
    local namespace=$2;
    if [[ $(helm delete --purge $releaseName) ]]; then
        log "Helm release $rls deleted"
    fi
    if [[ $(kubectl delete namespace $namespace) ]]; then
      log "Namespace $ns deleted"
    fi
    if [[ $(kubectl wait --for=delete ns/${namespace} --timeout=60s) ]]; then
      log "Namespace $ns deleted completed waiting"
    fi
   if [[ $(kubectl delete pvc data-${releaseName}-postgresql-0 -n ${namespace};) ]]; then
      log "pvc ${releaseName}-postgresql-0 deleted"
    fi
    if [[ $(kubectl wait --for=delete pvc/data-${releaseName}-postgresql-0 -n ${namespace} --timeout=60s;) ]]; then
      log "pvc ${releaseName}-postgresql-0 deleted wait finished"
    fi
    set -x
  }


function setup_lum_k8() {
  trap 'fail' ERR
    local releaseName=$1;
    local namespace=$2;

    # Get license-usage-manager repo here
    # point to path where cloned repo exists
    ## TODO change to master once merged in
    ## TODO use a helm registry -- would be better location
    rm -frd kubernetes/license-usage-manager
    git clone "https://gerrit.acumos.org/r/license-usage-manager" kubernetes/license-usage-manager
    pathToLumHelmChart=./kubernetes/license-usage-manager/lum-helm
    kubectl create namespace ${namespace};
    create_acumos_registry_secret ${namespace}
    replace_env kubernetes/values.yaml
    # TEMP fix for external name - making it easier for portal to consume in acumos namespace
    replace_env kubernetes/external-name.yaml
    # ## copy in dependencies
    helm dependency build       ${pathToLumHelmChart}
    helm install -f kubernetes/values.yaml  --name $releaseName  --namespace ${namespace} --debug  ${pathToLumHelmChart}
    kubectl apply -f  kubernetes/external-name.yaml
  set -x
}
action=$1
if [[ "$action" == "" ]]; then action=all; fi
LUM_RELEASE_NAME=license-clio;
LUM_NAMESPACE=acumos-license;
LUM_CHART_NAME=lum-helm
// TODO default port is 8080 from helm chart -- remove hard coding here
LUM_EXTERNAL_NAME=$LUM_RELEASE_NAME-$LUM_CHART_NAME.$LUM_NAMESPACE.svc.cluster.local
LUM_EXTERNAL_PORT=8080

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]];
  then export AIO_ROOT="$(cd ..; pwd -P)";
fi

source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh

if [[ "$action" == "clean" || "$action" == "all" ]]; 
  then cleanup_lum_k8 $LUM_RELEASE_NAME $LUM_NAMESPACE;
fi
if [[ "$action" == "setup" || "$action" == "all" ]];
  then setup_lum_k8  $LUM_RELEASE_NAME $LUM_NAMESPACE;
fi

cd $WORK_DIR
