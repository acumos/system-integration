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
# $ bash setup_ingress.sh <AIO_ROOT>
#   AIO_ROOT: path to AIO folder where environment files are
#

function clean_ingress() {
  trap 'fail' ERR

  log "Cleanup any ingress-related resources"
  if [[ $(helm delete --purge nginx-ingress) ]]; then
    log "Helm release nginx-ingress deleted"
  fi
  if [[ $($k8s_cmd delete secret -n $ACUMOS_NAMESPACE ingress-cert) ]]; then
    log "Secret ingress-cert deleted"
  fi
  ings=$($k8s_cmd get ingress -n $ACUMOS_NAMESPACE | awk '/-ingress/{print $1}')
  for ing in $ings; do
    if [[ $($k8s_cmd delete ingress -n $ACUMOS_NAMESPACE $ing) ]]; then
      log "Ingress $ing deleted"
    fi
  done
}

function setup_ingress() {
  trap 'fail' ERR

  log "Install nginx ingress controller via Helm"
  cat <<EOF >ingress-cert-values.yaml
controller:
  service:
    externalIPs: [$ACUMOS_HOST_IP]
EOF
  helm install --name nginx-ingress --namespace $ACUMOS_NAMESPACE \
    --set-string controller.config.proxy-body-size="0" \
    -f ingress-cert-values.yaml stable/nginx-ingress

  log "Create ingress-cert secret using cert for $ACUMOS_DOMAIN"
  get_host_info
  if [[ "$HOST_OS" == "macos" ]]; then
    b64crt=$(cat $AIO_ROOT/certs/acumos.crt | base64)
    b64key=$(cat $AIO_ROOT/certs/acumos.key | base64)
  else
    b64crt=$(cat $AIO_ROOT/certs/acumos.crt | base64 -w 0)
    b64key=$(cat $AIO_ROOT/certs/acumos.key | base64 -w 0)
  fi
  cat <<EOF >ingress-cert-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ingress-cert
  namespace: $ACUMOS_NAMESPACE
data:
  tls.crt: $b64crt
  tls.key: $b64key
type: kubernetes.io/tls
EOF
  $k8s_cmd create -f ingress-cert-secret.yaml

  log "Create ingress resources for services"
  if [[ ! -d deploy ]]; then mkdir deploy; fi
  cp templates/* deploy/.
  replace_env deploy
  ings=$(ls deploy)
  for ing in $ings; do
    $k8s_cmd create -f deploy/$ing
  done
}

if [[ $# -lt 1 ]]; then
  cat <<'EOF'
Usage:
  For k8s-based deployment, run this script on the AIO host or a workstation
  connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
  $ bash setup_ingress.sh <AIO_ROOT>
    AIO_ROOT: path to AIO folder where environment files are
EOF
  echo "All parameters not provided"
  exit 1
fi

WORK_DIR=$(pwd)
export AIO_ROOT=$1
source $AIO_ROOT/acumos_env.sh
source $AIO_ROOT/utils.sh
trap 'fail' ERR
cd $AIO_ROOT/ingress
clean_ingress
setup_ingress
cd $WORK_DIR
