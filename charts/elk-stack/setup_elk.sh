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
# $ bash setup_elk.sh <ACUMOS_ELK_DOMAIN> <K8S_DIST> [prep]
#   ACUMOS_ELK_DOMAIN: hostname or FQDN of ELK service. Must be resolvable locally
#     or thru DNS. Can be the hostname of the k8s master node.
#   K8S_DIST: generic|openshift
#   prep: (optional) run prerequisite setup steps (requires sudo)
#

function clean_elk() {
  trap 'elk_fail' ERR
  if [[ $(helm list elk) ]]; then
    helm delete --purge elk
    echo "Helm release elk deleted"
  fi
  delete_namespace $ACUMOS_ELK_NAMESPACE
  # The PVC sometimes takes longer to be deleted than the namespace, probably
  # due to PV data recycle operations; this can block later re-creation...
  delete_pvc elasticsearch-data $ACUMOS_ELK_NAMESPACE

  if [[ "$prep" == "prep" ]]; then
    reset_pv elasticsearch-data $ACUMOS_ELK_NAMESPACE \
      $ACUMOS_ELASTICSEARCH_DATA_PV_SIZE "1000:1000"
  fi
  cleanup_snapshot_images
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
  helm repo update
  helm install -n elk --namespace $ACUMOS_ELK_NAMESPACE .

  log "Wait for all elk-stack pods to be Running"
  apps="elasticsearch kibana logstash"
  for app in $apps; do
    wait_running $app $ACUMOS_ELK_NAMESPACE
  done
}

trap 'elk_fail' ERR

if [[ $# -lt 2 ]]; then
  cat <<'EOF'
Usage:
  $ bash setup_elk.sh <ACUMOS_ELK_DOMAIN> <K8S_DIST> [prep]
    ACUMOS_ELK_DOMAIN: hostname or FQDN of ELK service. Must be resolvable locally
      or thru DNS. Can be the hostname of the k8s master node.
    K8S_DIST: generic|openshift
    prep: (optional) run prerequisite setup steps (requires sudo)
EOF
  echo "All parameters not provided"
  exit 1
fi

set -x
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ../../AIO; pwd -P)"; fi
source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh
export ACUMOS_ELK_DOMAIN=$1
export DEPLOYED_UNDER=k8s
export K8S_DIST=$2
prep=$3

if [[ "$prep" == "prep" ]]; then
  verify_ubuntu_or_centos
  export ACUMOS_ELK_HOST=$(hostname)
fi

if [[ -e elk_env.sh ]]; then
  source elk_env.sh
fi
get_host_ip $ACUMOS_ELK_HOST
source setup_elk_env.sh

clean_elk
setup_elk

sedi 's/DEPLOY_RESULT=.*/DEPLOY_RESULT=success/' elk_env.sh
cp elk_env.sh $AIO_ROOT/.
cd $WORK_DIR
