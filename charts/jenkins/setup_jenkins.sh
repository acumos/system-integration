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
# What this is: script to setup a Jenkins server under k8s with Nginx-based ingress.
#
# Prerequisites:
# - k8s cluster deployed
# - k8s ingress controller deployed at K8S_INGRESS_DOMAIN and secret
#   'ingress-cert' created per charts/ingress/setup_ingress_controller.sh.
#
# Usage:
# For k8s-based deployment, run this script on the k8s master or a workstation
# connected to the k8s cluster via kubectl.
# $ bash setup_jenkins.sh <setup|clean|all> <NAMESPACE> <K8S_INGRESS_ORIGIN>
#   setup|clean|all: action to take
#   K8S_INGRESS_DOMAIN: domain assigned to the k8s cluster ingress controller
#   NAMESPACE: k8s namespace to deploy under (will be created if not existing)
#

function clean_jenkins() {
  trap 'fail' ERR

  if [[ $(helm delete --purge jenkins) ]]; then
    log "Helm release jenkins deleted"
  fi
  # Helm delete does not remove PVC
  if [[ $(kubectl delete pvc -n $NAMESPACE jenkins) ]]; then
    log "PVC deleted for Jenkins"
  fi
  # Ingress is managed directly, not by Helm
  if [[ $(kubectl delete ingress -n $NAMESPACE jenkins-ingress) ]]; then
    log "Ingress deleted for Jenkins"
  fi
}

function setup_jenkins() {
  trap 'fail' ERR

  if [[ -e deploy ]]; then rm -rf deploy; fi
  mkdir deploy

  log "Update values.yaml as input to Helm for deploying the Jenkins chart"
  cp values.yaml deploy/.
  get_host_ip $K8S_INGRESS_DOMAIN
  sedi "s/<NAMESPACE>/$NAMESPACE/g" deploy/values.yaml
  sedi "s/<K8S_INGRESS_DOMAIN>/$K8S_INGRESS_DOMAIN/g" deploy/values.yaml
  get_host_ip $K8S_INGRESS_DOMAIN
  sedi "s/<HOST_IP>/$HOST_IP/g" deploy/values.yaml

  log "Resulting values.yaml:"
  cat values.yaml

  log "Install Jenkins via Helm"
  helm install --name jenkins -f values.yaml stable/jenkins

  log "Setup ingress for Jenkins"
  cp jenkins-ingress.yaml deploy/.
  sedi "s/<NAMESPACE>/$NAMESPACE/g" deploy/jenkins-ingress.yaml
  sedi "s/<K8S_INGRESS_DOMAIN>/$K8S_INGRESS_DOMAIN/g" deploy/jenkins-ingress.yaml
  kubectl create -f deploy/jenkins-ingress.yaml

  log "Wait for Jenkins to be ready"
  echo "" > headers.txt
  t=0
  until [[ $(grep -c -i 'X-Jenkins:' headers.txt) -gt 0 ]]; do
    sleep 10
    t=$((i+10))
    if [[ $t -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      rm $jsoninp $jsonout
      fail "Jenkins is not ready after $ACUMOS_SUCCESS_WAIT_TIME seconds"
    fi
    curl -s -o /dev/null -D headers.txt -vL -k https://$K8S_INGRESS_DOMAIN/jenkins/api/
  done
}

if [[ $# -lt 3 ]]; then
  cat <<'EOF'
Usage:
 For k8s-based deployment, run this script on the k8s master or a workstation
 connected to the k8s cluster via kubectl.
 $ bash setup_jenkins.sh <setup|clean|all> <NAMESPACE> <K8S_INGRESS_DOMAIN>
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

action=$1
NAMESPACE=$2
K8S_INGRESS_DOMAIN=$3
K8S_DIST=generic
k8s_cmd=kubectl
k8s_nstype=namespace
if [[ "$action" == "clean" || "$action" == "all" ]]; then clean_jenkins; fi
if [[ "$action" == "setup" || "$action" == "all" ]]; then setup_jenkins; fi
cd $WORK_DIR
