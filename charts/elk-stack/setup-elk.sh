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
# What this is: script to setup the ELK stack for Acumos using Helm
#
# Prerequisites:
# - kubernetes cluster with helm installed
# - MariaDB and Acumos AIO installed, environment files in folder AIO_ROOT
# - If calling directly, e.g. to setup the elk-stack prior to installing the
#   Acumos core platform, create an acumos-env.sh file in this folder, with
#   at minimum the lines, set appropriately per your deployment environmnemt.
#   export ACUMOS_ELK_DOMAIN=<domain name>
#   export ACUMOS_ELK_HOST=<host name> (may be the same as domain name)
#
# Usage:
# $ bash setup-elk.sh <k8s_dist>
#   k8s_dist: generic|openshift
#

function elk_fail() {
  trap - ERR
  reason="$1"
  if [[ "$1" == "" ]]; then reason="unknown failure at $fname $fline"; fi
  sed -i -- 's/DEPLOY_RESULT=.*/DEPLOY_RESULT=fail/' elk-env.sh
  sed -i -- "s/FAIL_REASON=.*~FAIL_REASON=$reason~/" elk-env.sh
  log "$reason"
  exit 1
}

function log() {
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  echo; echo "$fname:$fline ($(date)) $1"
}

function sedi () {
    sed --version >/dev/null 2>&1 && sed -i -- "$@" || sed -i "" "$@"
}

function replace_env() {
  trap 'elk_fail' ERR
  echo "Set variable values in k8s templates at $1"
  if [[ -d $1 ]]; then
    files="$1/*.yaml"
    vars=$(grep -Rho '<[^<.]*>' $1/* | sed 's/<//' | sed 's/>//' | sort | uniq)
  else
    files=$1
    vars=$(grep -Rho '<[^<.]*>' $1 | sed 's/<//' | sed 's/>//' | sort | uniq)
  fi
  for f in $files; do
    for v in $vars ; do
      eval vv=\$$v
      sedi "s~<$v>~$vv~g" $f
    done
  done
}

function clean_elk() {
  trap 'elk_fail' ERR
  if [[ $(helm list elk) ]]; then
    helm delete --purge elk
  fi
  delete_namespace $ACUMOS_ELK_NAMESPACE
  # The PVC sometimes takes longer to be deleted than the namespace, probably
  # due to PV datta recycle operations; this can block later re-creation...
  delete_pvc elasticsearch-data $ACUMOS_ELK_NAMESPACE
}

function setup_elk() {
  trap 'elk_fail' ERR
  set_k8s_env
  create_namespace $ACUMOS_ELK_NAMESPACE
  create_acumos_registry_secret $ACUMOS_ELK_NAMESPACE
  setup_pvc elasticsearch-data $ACUMOS_ELK_NAMESPACE $ACUMOS_ELASTICSEARCH_DATA_PV_SIZE
  replace_env templates/elasticsearch
  replace_env templates/kibana
  replace_env templates/logstash
  replace_env values.yaml
  log "Create the elk Helm release"
  helm install -n elk --namespace $ACUMOS_ELK_NAMESPACE .

  log "Wait for all elk-stack pods to be Running"
  apps="elasticsearch kibana logstash"
  for app in $apps; do
    wait_running $app $ACUMOS_ELK_NAMESPACE
  done
}

trap 'elk_fail' ERR

action=$1
export DEPLOYED_UNDER=k8s
export K8S_DIST=$2
source ../../AIO/utils.sh
if [[ -e elk-env.sh ]]; then
  source elk-env.sh
  get_host_ip $ACUMOS_ELK_HOST
fi
source setup-elk-env.sh

if [[ "$1" == "" ]]; then
  elk_fail "Please specify the kubernetes distribution when running this script"
fi
export DEPLOYED_UNDER=k8s
export K8S_DIST=$1

clean_elk
setup_elk

sed -i -- 's/DEPLOY_RESULT=.*/DEPLOY_RESULT=success/' elk-env.sh
