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
# - If installing just CouchDB, set at least these values in
#   system-integration/AIO/acumos_env.sh
#     export AIO_ROOT=<absolute path of folder system-integration/AIO>
#     export ACUMOS_DOMAIN=<domain name>
#
# Usage:
# For k8s-based deployment, run this script on the k8s master or a workstation
# connected to the k8s cluster via kubectl.
# $ bash setup_couchdb.sh <setup|clean|all> <NAMESPACE>
#   setup|clean|all: action to take
#   NAMESPACE: k8s namespace to deploy under
#

function clean_couchdb() {
  trap 'fail' ERR

  if [[ $(helm delete --purge $NAMESPACE-couchdb) ]]; then
    log "Helm release $NAMESPACE-couchdb deleted"
  fi
  # Helm delete does not remove PVC
  delete_pvc $NAMESPACE couchdb-volumeclaim
}

function setup_couchdb() {
  trap 'fail' ERR

  log "Install couchdb via Helm"

  #  https://github.com/helm/charts/tree/master/stable/couchdb was deprecated
  helm repo add couchdb https://apache.github.io/couchdb-helm
  ACUMOS_COUCHDB_UUID=$(uuidgen)
  update_acumos_env ACUMOS_COUCHDB_UUID $ACUMOS_COUCHDB_UUID force
  mkdir -p deploy
  cat <<EOF >deploy/values.yaml
service:
  type: NodePort
couchdbConfig:
  couchdb:
    uuid: $ACUMOS_COUCHDB_UUID
    require_valid_user: true
EOF

  if [[ "$K8S_DIST" == "openshift" ]]; then
    cat <<EOF >>deploy/values.yaml
annotations:
  openshift.io/scc: privileged
EOF
  fi
  helm install --name $NAMESPACE-couchdb --namespace $NAMESPACE \
    -f deploy/values.yaml couchdb/couchdb

  ACUMOS_COUCHDB_PASSWORD=$(kubectl get secret -n $NAMESPACE $NAMESPACE-couchdb-couchdb -o go-template='{{ .data.adminPassword }}' | base64 --decode)
  update_acumos_env ACUMOS_COUCHDB_PASSWORD $ACUMOS_COUCHDB_PASSWORD force

  local t=0
  while [[ "$(helm list $NAMESPACE-couchdb --output json | jq -r '.Releases[0].Status')" != "DEPLOYED" ]]; do
    if [[ $t -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      fail "couchdb is not ready after $ACUMOS_SUCCESS_WAIT_TIME seconds"
    fi
    log "$NAMESPACE-couchdb Helm release is not yet Deployed, waiting 10 seconds"
    sleep 10
    t=$((t+10))
  done

  if [[ "$ACUMOS_COUCHDB_VERIFY_READY" == "true" ]]; then
    log "Wait for couchdb to be ready"
    until kubectl get svc -n $NAMESPACE $NAMESPACE-couchdb-svc-couchdb; do
      if [[ $t -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
        fail "couchdb is not ready after $ACUMOS_SUCCESS_WAIT_TIME seconds"
      fi
      log "CouchDB service is not yet running, waiting 10 seconds"
      sleep 10
      t=$((t+10))
    done
    if [[ "$ACUMOS_COUCHDB_DOMAIN" == "$ACUMOS_NAMESPACE-couchdb-svc-couchdb" ]]; then
      if [[ "$ACUMOS_DEPLOY_AS_POD" == "true" ]]; then
        host=$NAMESPACE-couchdb-svc-couchdb; port=5984
      else
        port=$(kubectl get services -n $NAMESPACE $NAMESPACE-couchdb-svc-couchdb -o json | jq -r '.spec.ports[0].nodePort')
        host=$ACUMOS_DOMAIN
      fi
    else
      host=$ACUMOS_COUCHDB_DOMAIN
      port=$ACUMOS_COUCHDB_PORT
    fi
    until [[ $(curl -m 5 -u $ACUMOS_COUCHDB_USER:$ACUMOS_COUCHDB_PASSWORD http://$host:$port | grep -c couchdb) -gt 0 ]]; do
      if [[ $t -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
        fail "couchdb is not ready after $ACUMOS_SUCCESS_WAIT_TIME seconds"
      fi
      sleep 10
      t=$((t+10))
    done
  fi
}

if [[ $# -lt 2 ]]; then
  cat <<'EOF'
Usage:
 For k8s-based deployment, run this script on the k8s master or a workstation
 connected to the k8s cluster via kubectl.
 $ bash setup_couchdb.sh <setup|clean|all> <NAMESPACE>
   setup|clean|all: action to take
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
set_k8s_env
if [[ "$action" == "clean" || "$action" == "all" ]]; then clean_couchdb; fi
if [[ "$action" == "setup" || "$action" == "all" ]]; then setup_couchdb; fi
cd $WORK_DIR
