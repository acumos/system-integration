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
# - k8s cluster and namespace created
# - If deploying under a LoadBalancer supporting service environment (e.g. Azure AKS)
#   first create a service istance as below:
#     $ cd system-integration/charts/ingress
#     $ mkdir deploy
#     $ cp nginx-ingress-service.yaml deploy/.
#     # in nginx-ingress-service.yaml, replace <ACUMOS_NAMESPACE> with the required value
#     $ kubectl create -f deploy/nginx-ingress-service.yaml
#
# Usage:
# For k8s-based deployment, run this script on the AIO host or a workstation
# connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
# $ bash setup_ingress_controller.sh <NAMESPACE> <CERT> <KEY> [EXTERNAL_IP]
#   NAMESPACE: kubernetes namespace to use
#   CERT: path to server cert
#   KEY: path to server cert key
#   EXTERNAL_IP: (optional) external IP to specify
#

function clean_ingress() {
  trap 'fail' ERR

  if [[ $(helm delete --purge ${NAMESPACE}-nginx-ingress) ]]; then
    log "Helm release ${NAMESPACE}-nginx-ingress deleted"
  fi
  if [[ $(kubectl get namespace -n $NAMESPACE) ]]; then
    log "Cleanup any ingress-related resources"
    if [[ $(kubectl delete secret -n $NAMESPACE ingress-cert) ]]; then
      log "Secret ingress-cert deleted"
    fi
    ings=$(kubectl get ingress -n $NAMESPACE | awk '/-ingress/{print $1}')
    for ing in $ings; do
      kubectl delete ingress -n $NAMESPACE $ing
    done
  fi
}

function setup_ingress() {
  trap 'fail' ERR
  create_ingress_cert_secret $NAMESPACE $CERT $KEY

  log "Install nginx ingress controller via Helm"
  cat <<EOF >ingress-values.yaml
controller:
  podSecurityContext:
    privileged: true
  extraArgs:
    default-ssl-certificate: "$NAMESPACE/ingress-cert"
    enable-ssl-passthrough: ""
  service:
    type: NodePort
    nodePorts:
      http: $ACUMOS_INGRESS_HTTP_PORT
      https: $ACUMOS_INGRESS_HTTPS_PORT
EOF

if [[ "$ACUMOS_INGRESS_LOADBALANCER" == "true" ]]; then
  cat <<EOF >>ingress-values.yaml
    loadBalancerIP: $EXTERNAL_IP
  kind: Deployment
EOF
else
  cat <<EOF >>ingress-values.yaml
  kind: DaemonSet
  daemonset:
    useHostPort: true
EOF
fi

  helm repo update
  helm install --name ${NAMESPACE}-nginx-ingress --namespace $NAMESPACE \
    --set-string controller.config.proxy-body-size="0" \
    -f ingress-values.yaml stable/nginx-ingress

  local t=0
  while [[ "$(helm list ${NAMESPACE}-nginx-ingress --output json | jq -r '.Releases[0].Status')" != "DEPLOYED" ]]; do
    if [[ $t -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      fail "${NAMESPACE}-nginx-ingress is not ready after $ACUMOS_SUCCESS_WAIT_TIME seconds"
    fi
    log "${NAMESPACE}-nginx-ingress Helm release is not yet Deployed, waiting 10 seconds"
    sleep 10
    t=$((t+10))
  done
}

if [[ $# -lt 3 ]]; then
  cat <<'EOF'
Usage:
 For k8s-based deployment, run this script on the AIO host or a workstation
 connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
 $ bash setup_ingress_controller.sh <NAMESPACE> <CERT> <KEY> [EXTERNAL_IP]
   NAMESPACE: kubernetes namespace to use
   CERT: path to server cert
   KEY: path to server cert key
   EXTERNAL_IP: (optional) external IP to specify
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
NAMESPACE=$1
CERT=$2
KEY=$3
EXTERNAL_IP=$4
clean_ingress
setup_ingress
cd $WORK_DIR
