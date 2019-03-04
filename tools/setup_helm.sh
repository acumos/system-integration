#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2018 AT&T Intellectual Property. All rights reserved.
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
#. What this is: script to setup Helm as kubernetes chart manager
#.
#. Prerequisites:
#. - Kubernetes cluster deployed, e.g. via setup_k8s.sh
#.
#. Usage:
#. $ bash setup_helm.sh
#.

trap 'fail' ERR

function fail() {
  log "$1"
  exit 1
}

function log() {
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  echo; echo "$fname:$fline ($(date)) $1"
}

function setup_helm() {
  log "Setup helm"
  # Install Helm
  # per https://github.com/kubernetes/helm/blob/master/docs/install.md
  cd ~
  curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
  chmod 700 get_helm.sh
  ./get_helm.sh
  log "Initialize helm"
  helm init
#  nohup helm serve > /dev/null 2>&1 &
#  log "Run helm repo update"
#  helm repo update
  # TODO: Workaround for bug https://github.com/kubernetes/helm/issues/2224
  # For testing use only!
  kubectl create clusterrolebinding permissive-binding \
    --clusterrole=cluster-admin --user=admin --user=kubelet \
    --group=system:serviceaccounts;
  # TODO: workaround for tiller FailedScheduling (No nodes are available that 
  # match all of the following predicates:: PodToleratesNodeTaints (1).)
  # kubectl taint nodes $HOSTNAME node-role.kubernetes.io/master:NoSchedule-
  # Wait till tiller is running
  tiller_deploy=$(kubectl get pods --all-namespaces | grep tiller-deploy | awk '{print $4}')
  while [[ "$tiller_deploy" != "Running" ]]; do
    log "tiller-deploy status is $tiller_deploy. Waiting 60 seconds for it to be 'Running'"
    sleep 60
    tiller_deploy=$(kubectl get pods --all-namespaces | grep tiller-deploy | awk '{print $4}')
  done
  log "tiller-deploy status is $tiller_deploy"

  # Install services via helm charts from https://kubeapps.com/charts
  # e.g. helm install stable/dokuwiki
}

setup_helm
log "Setup is complete."
