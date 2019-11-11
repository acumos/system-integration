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
# $ bash setup_elk.sh <clean|prep|setup|all> <ACUMOS_ELK_DOMAIN> <K8S_DIST>
#   clean|prep|setup|all: action to execute
#   ACUMOS_ELK_DOMAIN: hostname or FQDN of ELK service. Must be resolvable locally
#     or thru DNS. Can be the hostname of the k8s master node.
#   K8S_DIST: generic|openshift
#

function clean_elk() {
  trap 'fail' ERR
  if [[ $(helm delete --purge $ACUMOS_ELK_NAMESPACE-elk) ]]; then
    log "Helm release $ACUMOS_ELK_NAMESPACE-elk deleted"
  fi
  log "Delete all ELK resources"
  wait_until_notfound "kubectl get pods -n $ACUMOS_ELK_NAMESPACE" elasticsearch
  wait_until_notfound "kubectl get pods -n $ACUMOS_ELK_NAMESPACE" kibana
  wait_until_notfound "kubectl get pods -n $ACUMOS_ELK_NAMESPACE" logstash
  clean_resource $ACUMOS_ELK_NAMESPACE deployment elk
  clean_resource $ACUMOS_ELK_NAMESPACE pods elk
  clean_resource $ACUMOS_ELK_NAMESPACE secret elk
  delete_pvc $ACUMOS_ELK_NAMESPACE $ACUMOS_ELASTICSEARCH_DATA_PVC_NAME
  cleanup_snapshot_images
}

function prep_elk() {
  trap 'fail' ERR
  verify_ubuntu_or_centos
  if [[ "$ACUMOS_CREATE_PVS" == "true" && "$ACUMOS_PVC_TO_PV_BINDING" == "true" ]]; then
    bash $AIO_ROOT/../tools/setup_pv.sh all /mnt/$ACUMOS_ELK_NAMESPACE \
      $ACUMOS_ELASTICSEARCH_DATA_PV_NAME \
      $ACUMOS_ELASTICSEARCH_DATA_PV_SIZE "1000:1000"
  fi
  create_namespace $ACUMOS_ELK_NAMESPACE
  if [[ "$K8S_DIST" == "openshift" ]]; then
    log "Workaround: Acumos AIO requires privilege to set PV permissions"
    oc adm policy add-scc-to-user privileged -z default -n $ACUMOS_ELK_NAMESPACE
  fi
}

function setup_elk() {
  trap 'fail' ERR
  set_k8s_env
  create_acumos_registry_secret $ACUMOS_ELK_NAMESPACE
  if [[ -e deploy ]]; then rm -rf deploy; fi
  mkdir deploy
  cp -r templates deploy/.
  replace_env deploy/templates/elasticsearch
  replace_env deploy/templates/kibana
  replace_env deploy/templates/logstash
  if [[ "$ACUMOS_CREATE_PVS" != "true" ]]; then
    export ACUMOS_ELASTICSEARCH_DATA_PV_NAME=""
  fi
  get_host_ip $ACUMOS_MARIADB_DOMAIN
  ACUMOS_MARIADB_IP=$HOST_IP
  cp *.yaml deploy/.
  if [[ "$ACUMOS_PVC_TO_PV_BINDING" != "true" ]]; then
    export ACUMOS_ELASTICSEARCH_DATA_PV_NAME=
  fi
  replace_env deploy/values.yaml

  log "Create the elk Helm release"
  helm repo update
  cd deploy
  helm install -n $ACUMOS_ELK_NAMESPACE-elk --namespace $ACUMOS_ELK_NAMESPACE .
  cd $WORK_DIR

  log "Wait for all elk-stack pods to be Running"
  apps="elasticsearch kibana logstash"
  for app in $apps; do
    wait_running $app $ACUMOS_ELK_NAMESPACE
  done

  ACUMOS_ELK_ELASTICSEARCH_PORT=$(kubectl get services -n $ACUMOS_ELK_NAMESPACE elasticsearch -o json | jq -r '.spec.ports[0].nodePort')
  update_elk_env ACUMOS_ELK_ELASTICSEARCH_PORT $ACUMOS_ELK_ELASTICSEARCH_PORT force
  ACUMOS_ELK_ELASTICSEARCH_INDEX_PORT=$(kubectl get services -n $ACUMOS_ELK_NAMESPACE elasticsearch -o json | jq -r '.spec.ports[1].nodePort')
  update_elk_env ACUMOS_ELK_ELASTICSEARCH_INDEX_PORT $ACUMOS_ELK_ELASTICSEARCH_INDEX_PORT force
  ACUMOS_ELK_LOGSTASH_PORT=$(kubectl get services -n $ACUMOS_ELK_NAMESPACE logstash -o json | jq -r '.spec.ports[0].nodePort')
  update_elk_env ACUMOS_ELK_LOGSTASH_PORT $ACUMOS_ELK_LOGSTASH_PORT force
  ACUMOS_ELK_KIBANA_PORT=$(kubectl get services -n $ACUMOS_ELK_NAMESPACE kibana -o json | jq -r '.spec.ports[0].nodePort')
  update_elk_env ACUMOS_ELK_KIBANA_PORT $ACUMOS_ELK_KIBANA_PORT force
}

if [[ $# -lt 1 ]]; then
  cat <<'EOF'
Usage:
$ bash setup_elk.sh <clean|prep|setup|all> <ACUMOS_ELK_DOMAIN> <K8S_DIST>
 clean|prep|setup|all: action to execute
 ACUMOS_ELK_DOMAIN: hostname or FQDN of ELK service. Must be resolvable locally
   or thru DNS. Can be the hostname of the k8s master node.
 K8S_DIST: generic|openshift
EOF
  echo "All parameters not provided"
  exit 1
fi

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ../../AIO; pwd -P)"; fi
source $AIO_ROOT/utils.sh
update_acumos_env AIO_ROOT $AIO_ROOT force
source $AIO_ROOT/acumos_env.sh
action=$1
export ACUMOS_ELK_DOMAIN=$2
export DEPLOYED_UNDER=k8s
export K8S_DIST=$3
set_k8s_env

if [[ -e elk_env.sh ]]; then
  source elk_env.sh
fi
if [[ "$ACUMOS_ELK_HOST" == "" ]]; then
  ACUMOS_ELK_HOST=$(echo $ACUMOS_ELK_DOMAIN | cut -d '.' -f 1)
fi
get_host_ip $ACUMOS_ELK_HOST
source setup_elk_env.sh
if [[ "$action" == "clean" || "$action" == "all" ]]; then clean_elk; fi
if [[ "$action" == "prep" || "$action" == "all" ]]; then prep_elk; fi
if [[ "$action" == "setup" || "$action" == "all" ]]; then setup_elk; fi
sedi 's/DEPLOY_RESULT=.*/DEPLOY_RESULT=success/' elk_env.sh
cp elk_env.sh $AIO_ROOT/.
cd $WORK_DIR
