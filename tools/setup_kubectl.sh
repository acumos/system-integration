#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017 AT&T Intellectual Property. All rights reserved.
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
# What this is: script to setup kubectl access to a k8s cluster
#
# Prerequisites:
# - Ubuntu Xenial/Bionic, Centos 7, MacOS 10.11-14, or Windows 7/10 x64 workstation
# - Privilege to install software on your workstation (or get it installed
#   prior to running this script)
# - k8s cluster installed and accessible via key-based SSH
# - for software installations, setup the shell env variables for
#   http_proxy and https_proxy, per your work location requirements
# - For Windows, git bash or equivalent installed and used to run this script
#
# Usage: on the workstation,
# $ bash setup_kubectl.sh <server> <user> <namespace>
#   server: IP address or hostname of k8s master node
#   user: user of k8s master node
#   namespace: namespace to use
#

function get_dist() {
  if [[ $(bash --version | grep -c -e redhat-linux -e pc-linux) -gt 0 ]]; then
    dist=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
    distver=$(grep -m 1 'VERSION_ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
  elif [[ $(bash --version | grep -c apple) -gt 0 ]]; then
    dist=macos
    distver=$(sw_vers | awk '/ProductVersion/{print $2}')
  elif [[ $(bash --version | grep -c pc-msys) -gt 0 ]]; then
    dist=windows
  else
    fail "Unsupported OS family"
  fi
}

function setup_prereqs() {
  trap 'fail' ERR
  if [[ ! $(which kubectl) ]]; then
    get_dist
    KUBE_VERSION=1.10.0
    if [[ "$dist" == "ubuntu" ]]; then
      sudo apt-get install -y curl
      if [[ $(dpkg -l | grep -c kubectl) -eq 0 ]]; then
        log "Install kubectl"
        # Install kubectl per https://kubernetes.io/docs/setup/independent/install-kubeadm/
        sudo apt-get update && sudo apt-get install -y apt-transport-https
        curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
        cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
        sudo apt-get update
        sudo apt-get -y install --allow-downgrades kubectl=${KUBE_VERSION}-00
      fi
    elif [[ "$dist" == "centos" ]]; then
      sudo yum -y update
      sudo rpm -Fvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
      sudo yum install -y curl
      sudo yum install --allow-downgrades kubectl=${KUBE_VERSION}-00
    elif [[ "$dist" == "macos" ]]; then
      if [[ ! $(which port) ]]; then
        log "Install Macports"
        # Per https://www.macports.org/install.php
        if [[ $(echo $distver | grep -c '10\.14') -gt 0 ]]; then
          curl -LO https://distfiles.macports.org/MacPorts/MacPorts-2.5.4-10.14-Mojave.pkg
        elif [[ $(echo $distver | grep -c '10\.13') -gt 0 ]]; then
          curl -LO https://distfiles.macports.org/MacPorts/MacPorts-2.5.4-10.13-HighSierra.pkg
        elif [[ $(echo $distver | grep -c '10\.12') -gt 0 ]]; then
          curl -LO https://distfiles.macports.org/MacPorts/MacPorts-2.5.4-10.12-Sierra.pkg
        elif [[ $(echo $distver | grep -c '10\.11') -gt 0 ]]; then
          curl -LO https://distfiles.macports.org/MacPorts/MacPorts-2.5.4-10.11-ElCapitan.pkg
        else
          fail "Unsupported MacOS version"
        fi
        sudo installer -pkg MacPorts*.pkg
      fi
      log "Install kubectl via Macports"
      # Per https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-with-macports-on-macos
      sudo port selfupdate
      sudo port install kubectl
    elif [[ "$dist" == "windows" ]]; then
      log "Install kubectl using pre-built executable"
      curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/windows/amd64/kubectl.exe
      log "Move kubectl into path at ~/bin"
      mv kubectl.exe ~/bin/kubectl
    else
      fail "Unsupported OS"
    fi
  fi
}

if [[ $# -lt 3 ]]; then
  cat <<'EOF'
Usage:
  Usage: on the workstation,
  $ bash setup_kubectl.sh <server> <user> <namespace>
    server: IP address or hostname of k8s master node
    user: user of k8s master node
    namespace: namespace to use
EOF
  echo "All parameters not provided"
  exit 1
fi

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
export AIO_ROOT="$(cd ../AIO; pwd -P)"
source $AIO_ROOT/utils.sh
server=$1
user=$2
namespace=$3
setup_prereqs

kubectl config delete-cluster $server && true
kubectl config delete-context $server-$namespace && true

ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $user@$server kubectl config view
APISERVER=$(ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  $user@$server kubectl config view | grep -m1 server | cut -f 2- -d ":" | tr -d " ")
if [[ "$APISERVER" == "" ]]; then
  fail "Unable to retrieve API server URL"
fi
log "APISERVER=$APISERVER"
SECRET=$(ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $user@$server \
  kubectl get secrets | grep -m1 ^default-token | cut -f1 -d ' ')
if [[ "$SECRET" == "" ]]; then
  fail "Unable to retrieve default-token secret"
fi
log "SECRET=$SECRET"
TOKEN=$(ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $user@$server \
  kubectl describe secret $SECRET | grep -E '^token' | cut -f2 -d ':' | tr -d " ")
if [[ "$TOKEN" == "" ]]; then
  fail "Unable to retrieve token"
fi
log "TOKEN=$TOKEN"
curl $APISERVER/api --header "Authorization: Bearer $TOKEN" --insecure

kubectl config set-cluster $server --server=$APISERVER \
  --insecure-skip-tls-verify=true
kubectl config set-context $server-$namespace --cluster=$server \
  --user=$user --namespace=$namespace
kubectl config set-credentials $user --token=$TOKEN
kubectl config use-context $server-$namespace

if [[ $(kubectl get namespaces | grep -c kube-system) -gt 0 ]]; then
  log "Setup is complete!"
else
  fail "Setup failed"
fi

cd $WORK_DIR
