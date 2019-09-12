#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2019 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
# What this is: script to setup a CouchDB server under k8s with Nginx-based ingress.
#
# Prerequisites:
# - k8s cluster deployed
# - k8s ingress controller deployed at K8S_INGRESS_DOMAIN and secret
#   'ingress-cert' created per charts/ingress/setup_ingress_controller.sh.
#
# Usage:
# For k8s-based deployment, run this script on the k8s master or a workstation
# connected to the k8s cluster via kubectl.
# $ bash setup_couchdb.sh <setup|clean|all> <NAMESPACE> <K8S_INGRESS_ORIGIN>
#   setup|clean|all: action to take
#   K8S_INGRESS_DOMAIN: domain assigned to the k8s cluster ingress controller
#   NAMESPACE: k8s namespace to deploy under (will be created if not existing)
#

function clean_couchdb() {
  trap 'fail' ERR

  if [[ $(helm delete --purge couchdb) ]]; then
    log "Helm release couchdb deleted"
  fi
  # Helm delete does not remove PVC
  delete_pvc $NAMESPACE couchdb-volumeclaim
}

function setup_couchdb() {
  trap 'fail' ERR

  log "Install couchdb via Helm"
  # Sometimes get Error: failed to download "stable/couchdb" (hint: running `helm repo update` may help)
  helm repo update
  # Per https://github.com/helm/charts/tree/master/stable/couchdb
  helm install --name couchdb --namespace $NAMESPACE \
    --set service.type=NodePort \
    stable/couchdb

  log "Wait for couchdb to be ready"
  local t=0
  until kubectl get svc -n $NAMESPACE couchdb-svc-couchdb; do
    if [[ $t -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      fail "couchdb is not ready after $ACUMOS_SUCCESS_WAIT_TIME seconds"
    fi
    log "CouchDB service is not yet running, waiting 10 seconds"
    sleep 10
    t=$((t+10))
  done
  local ACUMOS_COUCHDB_PORT=$(kubectl get services -n $NAMESPACE couchdb-svc-couchdb -o json | jq -r '.spec.ports[0].nodePort')
  update_acumos_env ACUMOS_COUCHDB_PORT $ACUMOS_COUCHDB_PORT force
  until [[ $(curl -v http://$ACUMOS_COUCHDB_DOMAIN:$ACUMOS_COUCHDB_PORT | grep -c couchdb) -gt 0 ]]; do
    if [[ $t -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      fail "couchdb is not ready after $ACUMOS_SUCCESS_WAIT_TIME seconds"
    fi
    sleep 10
    t=$((t+10))
  done
}

if [[ $# -lt 3 ]]; then
  cat <<'EOF'
Usage:
 For k8s-based deployment, run this script on the k8s master or a workstation
 connected to the k8s cluster via kubectl.
 $ bash setup_couchdb.sh <setup|clean|all> <NAMESPACE> <K8S_INGRESS_DOMAIN>
   setup|clean|all: action to take
   K8S_INGRESS_DOMAIN: origin (FQDN:port) assigned to the k8s cluster ingress controller
   NAMESPACE: k8s namespace to deploy under (will be created if not existing)
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
source $AIO_ROOT/acumos_env.sh

action=$1
NAMESPACE=$2
K8S_INGRESS_DOMAIN=$3
K8S_DIST=generic
k8s_cmd=kubectl
k8s_nstype=namespace
if [[ "$action" == "clean" || "$action" == "all" ]]; then clean_couchdb; fi
if [[ "$action" == "setup" || "$action" == "all" ]]; then setup_couchdb; fi
cd $WORK_DIR
