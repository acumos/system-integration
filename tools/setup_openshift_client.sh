#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2018 AT&T Intellectual Property. All rights reserved.
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
# What this is: Setup script for the OpenShift client (oc) on a workstation
#
# Prerequisites:
# - Ubuntu Xenial/Bionic or Centos 7 workstation
# - Openshift cluster setup, with key-based SSH access from workstation
#
#. Usage: on the workstation
#. $ bash setup_openshift_client.sh <master> <username> [namespace]
#.   master: IP of the OpenShift cluster master
#.   username: username on the server where the master was installed (this is
#.     the user who setup the cluster, and for which key-based SSH is setup)
#.   namespace: optional namespace to set for the logged-in user context

trap 'fail' ERR

function fail() {
  log "$1"
  exit 1
}

function log() {
  set +x
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  echo; echo "$fname:$fline ($(date)) $1"
  set -x
}

setup_client() {
  if [[ "$(which oc)" == "" ]];then 
    log "Download the OpenShift binaries from GitHub"
    wget https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz
    tar xf openshift-origin-client-tools-*.tar.gz
    cd openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit
    sudo mv k* o* /usr/local/sbin/
  fi

  if [[ ! -e openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit ]]; then
    log "Download the OpenShift binaries from GitHub"
    wget https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz
    sudo tar xf openshift-origin-client-tools-*.tar.gz
    cd openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit
    sudo mv k* o* /usr/local/sbin/
  fi

  log "Setup kube config"
  token=$(ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    $username@$master \
    /usr/local/sbin/kubectl config view --raw -o jsonpath='{.users[].user.token}')

  oc config set-cluster $master --server=https://$master:8443 --insecure-skip-tls-verify=true
  oc config set-context $master --cluster=$master --user=admin-$master $namespace
  oc config set-credentials admin-$master --token=$token
  oc config use-context $master
}

master=$1
username=$2
if [[ "$3" != "" ]]; then namespace="--namespace=$3"; fi
setup_client

log "All done!"
echo "You are setup to use account 'admin' at cluster $master"
echo "Log in using 'oc login -u admin -p any'"
echo "Then issue a command e.g.'oc get pods --all-namespaces'"
