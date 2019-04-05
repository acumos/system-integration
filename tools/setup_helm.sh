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
# What this is: script to setup Helm as kubernetes chart manager
#
# Prerequisites:
# - Linux (Ubuntu Xenial/Bionic) host for the k8s cluster
# - Kubernetes cluster deployed, e.g. via setup_k8s.sh or setup_openshift.sh
# - If running on a remote workstation, access to the k8s cluster established
#   e.g. via setup_kubectl.sh or setup_openshift_client.sh
#
# Usage:
# $ bash setup_helm.sh
#

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
  trap 'fail' ERR
  log "Setup helm"
  # Install Helm
  if [[ $(which oc) ]]; then
    # Per https://blog.openshift.com/getting-started-helm-openshift/
    log "Install the Helm client locally"
    curl -s https://storage.googleapis.com/kubernetes-helm/helm-v2.12.3-linux-amd64.tar.gz | tar xz
    cd linux-amd64
    sudo cp helm /usr/bin/helm
    helm init --client-only
    export TILLER_NAMESPACE=kube-system
    oc project kube-system
    log "Install the tiller service on the openshift cluster"
    oc process \
     -f https://github.com/openshift/origin/raw/master/examples/helm/tiller-template.yaml\
     -p TILLER_NAMESPACE="${TILLER_NAMESPACE}" \
     -p HELM_VERSION=v2.12.3 | oc create -f -
    log "Grant tiller the RBAC permission to act as a cluster-admin service account"
    kubectl create clusterrolebinding tiller-binding \
      --clusterrole=cluster-admin --serviceaccount ${TILLER_NAMESPACE}:tiller
#    oc policy add-role-to-user admin "system:serviceaccount:${TILLER_NAMESPACE}:tiller"
  else
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
  fi

  # TODO: workaround for tiller FailedScheduling (No nodes are available that
  # match all of the following predicates:: PodToleratesNodeTaints (1).)
  # kubectl taint nodes $HOSTNAME node-role.kubernetes.io/master:NoSchedule-
  # Wait till tiller is running
  log "Waiting for tiller pod to be 'Running'"
  status="/tmp/$(uuidgen)"
  pod=$(kubectl get pods -n kube-system | awk '/tiller\-/{print $1}')
  kubectl get pods -o json -n kube-system $pod >$status
  i=0
  while [[ "$(jq -r '.status.phase' $status)" != "Running" ]]; do
    ((++i))
    if [[ $i -eq 60 ]]; then
      fail "tiller status is $(jq -r '.status.phase' $status) after 10 minutes"
      rm $status
    fi
    kubectl get pods -n kube-system | awk '/tiller\-/{print $1}'
    log "tiller status is $(jq -r '.status.phase' $status). Waiting 10 seconds..."
    sleep 10
    kubectl get pods -o json -n kube-system $pod >$status
  done
  log "tiller-deploy status is $(jq -r '.status.phase' $status)"
  rm $status

  log "Waiting until helm responds to clients"
  i=0
  while ! helm list ; do
    ((++i))
    if [[ $i -eq 30 ]]; then
      fail "Helm is not responding after 5 minutes"
    fi
    log "Helm server is not yet responding, waiting 10 seconds"
    sleep 10
  done

  # Install services via helm charts from https://kubeapps.com/charts
  # e.g. helm install stable/dokuwiki
}

trap 'fail' ERR
setup_helm
log "Setup is complete."
