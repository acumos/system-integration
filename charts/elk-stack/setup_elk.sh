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
#   Acumos core platform, create an acumos_env.sh file in this folder, with
#   at minimum the lines, set appropriately per your deployment environmnemt.
#   export ACUMOS_ELK_DOMAIN=<domain name>
#   export ACUMOS_ELK_HOST=<host name> (may be the same as domain name)
#
# Usage:
# Run this script on the AIO host or a workstation connected to the k8s cluster
# via kubectl (e.g. via tools/setup_kubectl.sh)
# $ bash setup_elk.sh <AIO_ROOT> <K8S_DIST>
#   AIO_ROOT: path to AIO folder where environment files are
#   K8S_DIST: generic|openshift
#

function elk_fail() {
  trap - ERR
  reason="$1"
  if [[ "$1" == "" ]]; then reason="unknown failure at $fname $fline"; fi
  sedi 's/DEPLOY_RESULT=.*/DEPLOY_RESULT=fail/' elk_env.sh
  sedi "s/FAIL_REASON=.*~FAIL_REASON=$reason~/" elk_env.sh
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
  replace_env templates/elasticsearch
  replace_env templates/kibana
  replace_env templates/logstash
  replace_env values.yaml

  if [[ "$K8S_DIST" == "openshift" ]]; then
    log "Workaround: Acumos AIO requires privilege for elasticsearch"
    oc adm policy add-scc-to-user privileged -z default -n $ACUMOS_ELK_NAMESPACE
  fi

  log "Create the elk Helm release"
  helm install -n elk --namespace $ACUMOS_ELK_NAMESPACE .

  log "Wait for all elk-stack pods to be Running"
  apps="elasticsearch kibana logstash"
  for app in $apps; do
    wait_running $app $ACUMOS_ELK_NAMESPACE
  done
}

trap 'elk_fail' ERR

if [[ $# -lt 2 ]]; then
  echo <<'EOF'
Usage:
  $ bash setup_elk.sh <AIO_ROOT> <K8S_DIST>
    AIO_ROOT: path to AIO folder where environment files are
    K8S_DIST: generic|openshift
EOF
  echo "All parameters not provided"
  exit 1
fi

WORK_DIR=$(pwd)
export AIO_ROOT=$1
export DEPLOYED_UNDER=k8s
export K8S_DIST=$2
source $AIO_ROOT/utils.sh
cd $AIO_ROOT/../charts/elk-stack
if [[ -e elk_env.sh ]]; then
  log "Using prepared elk_env.sh for customized environment values"
  source elk_env.sh
  get_host_ip $ACUMOS_ELK_HOST
fi
source setup_elk_env.sh

clean_elk
setup_elk

sedi 's/DEPLOY_RESULT=.*/DEPLOY_RESULT=success/' elk_env.sh
cd $WORK_DIR
