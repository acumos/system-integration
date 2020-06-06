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
# What this is: script to setup Zeppelin as a service of the Acumos platform.
# NOTE: experimental use only; does not yet include Acumos user authentication.
#
# Prerequisites:
# - kubernetes cluster installed
# - helm installed under the k8s cluster
# - kubectl and helm installed on the user's workstation
# - user workstation setup to use a k8s profile for the target k8s cluster
#   e.g. using the Acumos kubernetes-client repo tools
#   $ bash kubernetes-client/deploy/private/setup_kubectl.sh k8smaster ubuntu acumos
#
# Usage: on the user's workstation
# $ bash setup-zeppelin.sh <namespace>
#   namespace: namespace to deploy under
#   domain: domain name to use for ingress controller
#

function fail() {
  log "$1"
  cd $WORK_DIR
  exit 1
}

function log() {
  set +x
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  echo; echo "$fname:$fline ($(date)) $1"
  set -x
}

function sedi () {
    sed --version >/dev/null 2>&1 && sed -i -- "$@" || sed -i "" "$@"
}

function prereqs() {
  trap 'fail' ERR
  log "Setup prerequisites"
  # Per https://z2jh.jupyter.org/en/latest/setup-jupyterhub.html
  if [[ ! $(which helm) ]]; then
    # Install a helm client per https://github.com/helm/helm/releases"
    wget https://storage.googleapis.com/kubernetes-helm/helm-v2.12.3-linux-amd64.tar.gz
    gzip -d helm-v2.12.3-linux-amd64.tar.gz
    tar -xvf helm-v2.12.3-linux-amd64.tar
    sudo cp linux-amd64/helm /usr/local/sbin/.
    log "Initialize helm"
    helm init
  fi
}

function setup() {
  trap 'fail' ERR
  if [[ "$(helm list $namespace-zeppelin)" != "" ]]; then
    helm delete --purge $namespace-zeppelin
    log "Helm release $namespace-zeppelin deleted"
  fi

  log "Clone helm charts repo"
  tmp=/tmp/$(uuidgen)
  git clone --depth 1 https://github.com/helm/charts.git $tmp
  cd $tmp/stable/zeppelin

  log "Update zepellin chart to reference image apache/zeppelin"
  # update chart to use apache/zeppelin image as the default image is debian:8
  # based which is incompatible with Acumos
  sedi 's~dylanmei/zeppelin:0.7.2~apache/zeppelin:0.8.1~' values.yaml

  log "Update zeppelin chart to use only 'zeppelin' as service name"
  sedi 's/name: {{ .Release.Name }}-zeppelin/name: zeppelin/' values.yaml

#  log "Update zepellin chart to use ingress controller"
#  sedi 's/enabled: false/enabled: true/' values.yaml
#  sedi "s/zeppelin.local/zeppelin.$domain/" values.yaml
#  sedi 's~path: /~path: /zeppelin~' values.yaml

# Uncomment this if you want to deploy Zeppelin with a nodePort; otherwise
# Kong will be setup to proxy to the Zeppelin service per the ingress settings
  log "Update zepellin chart to use nodePort for the zeppelin service"
  sedi 's/ClusterIP/NodePort/' templates/svc.yaml

  log "Install the zepellin helm chart"
  helm repo update
  helm upgrade --install ${namespace}-zeppelin --namespace $namespace .

  log "Wait for zeppelin to be running"
  i=0
  status=$(kubectl get pods -n $namespace | awk '/zeppelin/ {print $3}')
  while [[ "$status" != "Running" ]]; do
    helm list zeppelin
    kubectl get svc -n $namespace | grep zeppelin
    kubectl get pods -n $namespace | grep zeppelin
    i=$((i+1))
    if [[ $i -eq 30 ]]; then
      fail "Zeppelin not running after 5 minutes"
    fi
    echo "Waiting..."
    sleep 10
    status=$(kubectl get pods -n $namespace | awk '/zeppelin/ {print $3}')
  done

  log "Deploy is complete!"
  rm -rf $tmp
  cluster=$(kubectl config get-contexts \
    $(kubectl config view | awk '/current-context/{print $2}') \
    | awk '/\*/{print $3}')
  server=$(kubectl config view \
    -o jsonpath="{.clusters[?(@.name == \"$cluster\")].cluster.server}" \
    | cut -d '/' -f 3 | cut -d ':' -f 1)
  nodePort=$(kubectl get svc -n $namespace -o json zeppelin | jq '.spec.ports[0].nodePort')
  echo "Access Zeppelin at http://$server:$nodePort"
}

WORK_DIR=$(pwd)
namespace=$1
domain=$2
prereqs
setup
cd $WORK_DIR
