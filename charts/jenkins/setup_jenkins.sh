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
# - k8s ingress controller deployed at K8S_INGRESS_ORIGIN and secret
#   'ingress-cert' created per charts/ingress/setup_ingress_controller.sh.
#
# Usage:
# For k8s-based deployment, run this script on the k8s master or a workstation
# connected to the k8s cluster via kubectl.
# $ bash setup_jenkins.sh <setup|clean|all> <NAMESPACE> <K8S_INGRESS_ORIGIN>
#   setup|clean|all: action to take
#   K8S_INGRESS_ORIGIN: domain assigned to the k8s cluster ingress controller
#   NAMESPACE: k8s namespace to deploy under (will be created if not existing)
#

function clean_jenkins() {
  trap 'fail' ERR

  if [[ $(helm delete --purge $ACUMOS_NAMESPACE-jenkins) ]]; then
    log "Helm release $ACUMOS_NAMESPACE-jenkins deleted"
  fi
  # Helm delete does not remove PVC
  if [[ $(kubectl delete pvc -n $NAMESPACE $NAMESPACE-jenkins) ]]; then
    while kubectl get pvc -n $NAMESPACE $NAMESPACE-jenkins; do
      log "Waiting for Jenkins PVC to be deleted"
      sleep 10
    done
    log "Jenkins PVC deleted"
  fi
  # Ingress is managed directly, not by Helm
  if [[ $(kubectl delete ingress -n $NAMESPACE jenkins-ingress) ]]; then
    log "Ingress deleted for Jenkins"
  fi
}

function setup_jenkins() {
  trap 'fail' ERR

  if [[ ! -e deploy ]]; then mkdir deploy; fi

  log "Update values.yaml as input to Helm for deploying the Jenkins chart"
  update_acumos_env ACUMOS_JENKINS_PASSWORD $(uuidgen)
  cp values.yaml deploy/.
  K8S_INGRESS_DOMAIN=$(echo $K8S_INGRESS_ORIGIN | cut -d ':' -f 1)
  get_host_ip $K8S_INGRESS_DOMAIN
  replace_env deploy/values.yaml

  log "Resulting values.yaml:"
  cat deploy/values.yaml

  log "Install Jenkins via Helm via customized chart"
  # helm repo update
  # helm install --name $ACUMOS_NAMESPACE-jenkins -f deploy/values.yaml stable/jenkins
  # TODO: fix for this workaround, e.g. a custom recycler that sets permissions
  # Customized chart is needed to enabler securityContextL privileged, to fix
  # issues with PV writeability
  log "Clone helm charts repo"
  tmp=/tmp/$(uuidgen)
  git clone https://github.com/helm/charts.git $tmp
  cp -r $tmp/stable/jenkins deploy/.
  sedi '/securityContext:/a\ \ \ \ \ \ \ \ privileged: true' deploy/jenkins/templates/jenkins-master-deployment.yaml
  sedi '/annotations:/a\ \ \ \ \ \ \ \ openshift.io\/scc: privileged' deploy/jenkins/templates/jenkins-master-deployment.yaml
  helm install --name $ACUMOS_NAMESPACE-jenkins -f deploy/values.yaml deploy/jenkins/.

  local t=0
  while [[ "$(helm list ${NAMESPACE}-jenkins --output json | jq -r '.Releases[0].Status')" != "DEPLOYED" ]]; do
    if [[ $t -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      fail "${NAMESPACE}-jenkins is not ready after $ACUMOS_SUCCESS_WAIT_TIME seconds"
    fi
    log "${NAMESPACE}-jenkins Helm release is not yet Deployed, waiting 10 seconds"
    sleep 10
    t=$((t+10))
  done

  if [[ "$ACUMOS_DEPLOY_INGRESS_RULES" == "true" ]]; then
    log "Setup ingress for Jenkins"
    cp jenkins-ingress.yaml deploy/.
    replace_env deploy/jenkins-ingress.yaml
    kubectl create -f deploy/jenkins-ingress.yaml
  fi

  log "Wait for Jenkins to be ready"
  local url="-k https://$K8S_INGRESS_ORIGIN/jenkins/api/"
  if [[ "$ACUMOS_DEPLOY_AS_POD" == "true" ]]; then
    url=$ACUMOS_JENKINS_API_URL
  fi
  echo "" > headers.txt
  t=0
  until [[ $(grep -c -i 'X-Jenkins:' headers.txt) -gt 0 ]]; do
    sleep 10
    t=$((t+10))
    if [[ $t -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      fail "Jenkins is not ready after $ACUMOS_SUCCESS_WAIT_TIME seconds"
    fi
    if [[ $(curl -s -o /dev/null -D headers.txt -L $url) == "" ]]; then
      log "Jenkins is not yet ready"
    fi
  done
}

if [[ $# -lt 3 ]]; then
  cat <<'EOF'
Usage:
 For k8s-based deployment, run this script on the k8s master or a workstation
 connected to the k8s cluster via kubectl.
 $ bash setup_jenkins.sh <setup|clean|all> <NAMESPACE> <K8S_INGRESS_ORIGIN>
   setup|clean|all: action to take
   NAMESPACE: k8s namespace to deploy under (will be created if not existing)
   K8S_INGRESS_ORIGIN: origin (FQDN:port) assigned to the k8s cluster ingress controller
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
# Setup AIO_ROOT again in case this script is run for standalone deployment
# (in that case AIO_ROOT may not be set in acumos_env.sh)
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ../../AIO; pwd -P)"; fi

action=$1
NAMESPACE=$2
K8S_INGRESS_ORIGIN=$3
K8S_DIST=generic
k8s_cmd=kubectl
k8s_nstype=namespace
if [[ "$action" == "clean" || "$action" == "all" ]]; then clean_jenkins; fi
if [[ "$action" == "setup" || "$action" == "all" ]]; then setup_jenkins; fi
cd $WORK_DIR
