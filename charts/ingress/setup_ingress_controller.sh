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
# $ bash setup_ingress_controller.sh <NAMESPACE> <EXTERNAL_IP> <CERT> <KEY>
#   NAMESPACE: kubernetes namespace to use
#   EXTERNAL_IP: external IP to specify
#   CERT: path to server cert
#   KEY: path to server cert key
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

  log "Create ingress-cert secret"
  get_host_info
  if [[ "$HOST_OS" == "macos" ]]; then
    b64crt=$(cat $CERT | base64)
    b64key=$(cat $KEY | base64)
  else
    b64crt=$(cat $CERT | base64 -w 0)
    b64key=$(cat $KEY | base64 -w 0)
  fi
  cat <<EOF >ingress-cert-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ingress-cert
  namespace: $NAMESPACE
data:
  tls.crt: $b64crt
  tls.key: $b64key
type: kubernetes.io/tls
EOF
  kubectl create -f ingress-cert-secret.yaml

  log "Install nginx ingress controller via Helm"
  cat <<EOF >ingress-values.yaml
controller:
  podSecurityContext:
    privileged: true
  service:
    nodePorts:
      http: $ACUMOS_INGRESS_HTTP_PORT
      https: $ACUMOS_INGRESS_HTTPS_PORT
    externalIPs: [$EXTERNAL_IP]
  extraArgs:
    default-ssl-certificate: "$NAMESPACE/ingress-cert"
    enable-ssl-passthrough: ""
EOF

  if [[ "$K8S_DIST" == "openshift" ]]; then
    sed -i 's/externalIPs:.*/type: NodePort/' ingress-values.yaml
  fi
  helm install --name ${NAMESPACE}-nginx-ingress --namespace $NAMESPACE \
    --set-string controller.config.proxy-body-size="0" \
    -f ingress-values.yaml stable/nginx-ingress
}

if [[ $# -lt 4 ]]; then
  cat <<'EOF'
Usage:
 For k8s-based deployment, run this script on the AIO host or a workstation
 connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
 $ bash setup_ingress_controller.sh <NAMESPACE> <EXTERNAL_IP> <CERT> <KEY>
   NAMESPACE: kubernetes namespace to use
   EXTERNAL_IP: external IP to specify
   CERT: path to server cert
   KEY: path to server cert key
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
EXTERNAL_IP=$2
CERT=$3
KEY=$4
clean_ingress
setup_ingress
cd $WORK_DIR
