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
# What this is: Setup script for the OpenShift client (oc) on a workstation.
# This allows cluster user to interact with the cluster without having to run
# commands on the cluster master node. This is required for tenants, who
# typically do not have login privilege on clusters for which they are a tenant.
#
# Prerequisites:
# - Ubuntu Xenial/Bionic or Centos 7 workstation
# - Openshift cluster setup, with key-based SSH access from workstation
#
# Usage: on the workstation
# $ bash setup_openshift_client.sh <master> <username> [namespace]
#   master: IP of the OpenShift cluster master
#   username: username on the server where the master was installed (this is
#     the user who setup the cluster, and for which key-based SSH is setup)
#   namespace: optional namespace to set for the logged-in user context

function get_dist() {
  trap 'fail' ERR
  if [[ $(bash --version | grep -c redhat-linux) -gt 0 ]]; then
    dist=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
  elif [[ $(bash --version | grep -c pc-linux) -gt 0 ]]; then
    dist=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
  elif [[ $(bash --version | grep -c apple) -gt 0 ]]; then
    dist=macos
  elif [[ $(bash --version | grep -c pc-msys) -gt 0 ]]; then
    dist=windows
  else
    fail "Unsupported OS family"
  fi
}

setup_client() {
  trap 'fail' ERR
  get_dist
  if [[ "$(which oc)" == "" ]];then
    if [[ "$dist" == "ubuntu" || "$dist" == "centos" ]]; then
      if [[ ! -e openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz ]]; then
        curl -LO https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz
      fi
      tar xf openshift-origin-client-tools-*.tar.gz
      cd openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit
      sudo mv kubectl oc /usr/local/sbin/.
    elif [[ "$dist" == "macos" ]]; then
      if [[ ! $(which brew) ]]; then
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
      fi
      brew update
      brew install openshift-cli
    elif [[ "$dist" == "windows" ]]; then
      if [[ ! -e openshift-origin-client-tools-v3.11.0-0cbc58b-windows.zip ]]; then
        curl -LO https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-windows.zip
      fi
      unzip -o openshift*.zip
      export PATH=$(pwd):$PATH
    fi
  fi

  log "Setup kube config"
  token=$(ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    $username@$master \
    kubectl config view --raw -o jsonpath='{.users[].user.token}')

  oc config set-cluster $master --server=https://$master:8443 --insecure-skip-tls-verify=true
  oc config set-context $master-$namespace --cluster=$master --user=admin $ns
  oc config set-credentials admin --token=$token
  oc config use-context $master-$namespace
}

if [[ $# -lt 3 ]]; then
  cat <<'EOF'
Usage:
 Usage: on the workstation
 $ bash setup_openshift_client.sh <master> <username> [namespace]
   master: IP of the OpenShift cluster master
   username: username on the server where the master was installed (this is
     the user who setup the cluster, and for which key-based SSH is setup)
   namespace: optional namespace to set for the logged-in user context
EOF
  echo "All parameters not provided"
  exit 1
fi

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ../AIO; pwd -P)"; fi
source $AIO_ROOT/utils.sh
master=$1
username=$2
namespace=$3
ns="--namespace=$namespace"
setup_client

log "All done!"
echo "You are setup to use account 'admin' at cluster $master"
echo "Log in using 'oc login -u admin -p any'"
echo "Then issue a command e.g. 'oc get pods --all-namespaces'"
