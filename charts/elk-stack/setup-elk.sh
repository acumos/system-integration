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
# - the following values are set in the shell environment, e.g. by sourcing the
#   mariadb-env.sh script prior to running this script
#   ACUMOS_CDS_DB
#   ACUMOS_MARIADB_HOST
#   ACUMOS_MARIADB_PORT
#   ACUMOS_MARIADB_USER
#   ACUMOS_MARIADB_USER_PASSWORD
#
# Usage:
# $ bash setup-elk.sh
#

function elk_fail() {
  trap - ERR
  reason="$1"
  if [[ "$1" == "" ]]; then reason="unknown failure at $fname $fline"; fi
  sed -i -- 's/DEPLOY_RESULT=.*/DEPLOY_RESULT=fail/' elk-env.sh
  sed -i -- "s/FAIL_REASON=.*~FAIL_REASON=$reason~" elk-env.sh
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

function setup_elk() {
  trap 'elk_fail' ERR
  ACUMOS_ELK_DOMAIN=$2
  log "Determining host IP address for $ACUMOS_ELK_DOMAIN"
  if [[ $(host $ACUMOS_ELK_DOMAIN | grep -c 'not found') -eq 0 ]]; then
    ACUMOS_ELK_HOST=$(host $ACUMOS_ELK_DOMAIN | head -1 | cut -d ' ' -f 4)
  elif [[ $(grep -c -P " $ACUMOS_ELK_DOMAIN( |$)" /etc/hosts) -gt 0 ]]; then
    ACUMOS_ELK_HOST=$(grep -P "$ACUMOS_ELK_DOMAIN( |$)" /etc/hosts | cut -d ' ' -f 1)
  else
    log "Please ensure $ACUMOS_ELK_DOMAIN is resolvable thru DNS or hosts file"
    fail "IP address of $ACUMOS_ELK_DOMAIN cannot be determined."
  fi

  replace_env templates/elasticsearch
  replace_env templates/kibana
  replace_env templates/logstash
  replace_env values.yaml
  helm install -n elk --namespace $ACUMOS_ELK_NAMESPACE .
}

trap 'elk_fail' ERR

action=$1
source setup-elk-env.sh

if [[ "$action" == "setup" ]]; then
  setup
else
  helm delete --purge elk
  kubectl delete pvc -n $ACUMOS_ELK_NAMESPACE $ELASTICSEARCH_DATA_PVC_NAME
  while kubectl get pvc -n $ACUMOS_ELK_NAMESPACE $ELASTICSEARCH_DATA_PVC_NAME ; do
    log "Waiting for PVC $ELASTICSEARCH_DATA_PVC_NAME to be deleted"
    sleep 10
  done
fi

sed -i -- 's/DEPLOY_RESULT=.*/DEPLOY_RESULT=success/' elk-env.sh
