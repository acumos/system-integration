#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2019 AT&T Intellectual Property. All rights reserved.
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
# What this is: script to setup an Nginx-based ingress controller and related
# ingress rules for the Acumos platform, as deployed under kubernetes. See
# https://github.com/helm/charts/tree/master/stable/nginx-ingress for more
# info.
#
# Prerequisites:
# - Acumos core components through oneclick_deploy.sh
#
# Usage:
# For k8s-based deployment, run this script on the AIO host or a workstation
# connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
# $ bash setup_ingress.sh
#
# Openshift
# oc login -u system:admin
# oc project default
# oc get -o yaml service/router dc/router clusterrolebinding/router-router-role serviceaccount/router > default-router-backup.yam
# git clone https://github.com/nginxinc/nginx-openshift-router
# cd nginx-openshift-router/src/nginx
# docker build -t nginx-openshift-router:0.2 .
# cd ~
# oc delete -f default-router-backup.yaml
# oc adm router router --images=nginx-openshift-router:0.2 --type=''

function clean_ingress() {
  trap 'fail' ERR
  ings=$(kubectl get ingress -n $ACUMOS_NAMESPACE | awk '/-ingress/{print $1}')
  for ing in $ings; do
    if [[ $(kubectl delete ingress -n $ACUMOS_NAMESPACE $ing) ]]; then
      log "Ingress $ing deleted"
    fi
  done
}

function setup_ingress() {
  trap 'fail' ERR

  bash $AIO_ROOT/../charts/ingress/setup_ingress_controller.sh $ACUMOS_NAMESPACE \
    $ACUMOS_HOST_IP $AIO_ROOT/certs/acumos.crt $AIO_ROOT/certs/acumos.key

  log "Create ingress resources for services"
  if [[ ! -d deploy ]]; then mkdir deploy; fi
  cp templates/* deploy/.
  replace_env deploy
  ings=$(ls deploy)
  for ing in $ings; do
    kubectl create -f deploy/$ing
  done
}

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ..; pwd -P)"; fi
source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh
clean_ingress
setup_ingress
cd $WORK_DIR
