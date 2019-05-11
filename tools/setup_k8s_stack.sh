#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
# What this is: Script to deploy a single-node kubernetes cluster and additional
# tools (Helm, Prometheus).
#
# Prerequisites:
# - Ubuntu Xenial/Bionic or Centos 7 server
# - All hostnames specified in acumos_env.sh must be DNS-resolvable on all hosts
#   (entries in /etc/hosts or in an actual DNS server)
# - For deployments behind proxies, set HTTP_PROXY and HTTPS_PROXY in acumos_env.sh
# - User running this script has:
#   - Installed docker per system-integration/tools/setup_docker.sh
#   - Added themselves to the docker group (sudo usermod -aG docker $USER)
#   - Logged out and back in, to activate docker group membership
# - cd to your home folder, as the root of this installation process
# - If you want to use a specific/updated/patched system-integration repo clone,
#   place that system-integration clone in the home folder
# - Then run the command below
#
# Usage:
# $ bash system-integration/AIO/k8s_stack.sh <clean|setup>
#   clean: remove all stack components
#   setup: setup all stack components
#

function clean_k8s() {
  # clean current environment
  if [[ "$K8S_DIST" == "openshift" ]]; then
    wget -O cleanup.sh \
      https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/cleanup.sh
    bash cleanup.sh
    if [[ $(which docker) ]]; then docker system prune -a -f; fi
    sudo yum erase -y docker-ce docker docker-engine docker.io
  else
    if [[ $(which kubeadm) ]]; then
      sudo kubeadm reset -f
      # Per https://github.com/cloudnativelabs/kube-router/issues/383 - coredns will
      # stay in "containerCreating" if it comes up before calico is ready
      sudo rm -rf /var/lib/cni/networks/k8s-pod-network/*
    fi
    # Avoid error later: [ERROR DirAvailable--var-lib-etcd]: /var/lib/etcd is not empty
    sudo rm -rf /var/lib/etcd/* && true
    if [[ $(which docker) ]]; then docker system prune -a -f; fi
    sudo apt-get purge -y docker-ce docker docker-engine docker.io
  fi
  sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
}

function setup_k8s() {
  trap 'fail' ERR
  # k8s setup
  # use a specific folder for this, to prevent errors in removing system-integration
  # on subsequent deployments (e.g. to re-clone or patch an existing clone)
  if [[ -e ~/k8s-deploy ]]; then
    while ! sudo rm -rf ~/k8s-deploy; do
      echo "Unable to remove ~/k8s-deploy... waiting 10 seconds"
      sleep 10
    done
  fi
  mkdir ~/k8s-deploy
  cd ~/k8s-deploy
  if [[ "$K8S_DIST" == "openshift" ]]; then
    bash ~/system-integration/tools/setup_openshift.sh
  else
    bash ~/system-integration/tools/setup_k8s.sh
    secret=$(kubectl get secrets | grep -m1 ^default-token | cut -f1 -d ' ')
    token=$(kubectl describe secret $secret | grep -E '^token' | cut -f2 -d':' | tr -d " ")
    echo "Token for setting up the k8s dashboard at https://$(hostname):32767"
    echo $token
  fi
}

if [[ $# -lt 1 ]]; then
  cat <<'EOF'
Usage:
  $ bash system-integration/AIO/k8s_stack.sh <clean|setup>
    clean: remove all stack components
    setup: setup all stack components
EOF
  echo "All parameters not provided"
  exit 1
fi

set -x
WORK_DIR=$(pwd)
cd $(dirname "$0")
export AIO_ROOT="$(cd ../AIO; pwd -P)"
source $AIO_ROOT/utils.sh
trap 'fail' ERR
verify_ubuntu_or_centos
if [[ "$1" == "setup" ]]; then
  setup_k8s
  bash ~/system-integration/tools/setup_helm.sh
  bash ~/system-integration/tools/setup_prometheus.sh
else
  clean_k8s
fi
cd $WORK_DIR
