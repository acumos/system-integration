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
# What this is: Script to install docker and docker-compose on a host, if needed
#
# Prerequisites:
# - Ubuntu Xenial or Centos 7 server
#
# Usage:
# - bash setup_docker.sh
#

function wait_dpkg() {
  # TODO: workaround for "E: Could not get lock /var/lib/dpkg/lock - open (11: Resource temporarily unavailable)"
  echo; echo "waiting for dpkg to be unlocked"
  while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
    sleep 1
  done
}

setup() {
  trap 'fail' ERR
  if [[ "$HOST_OS" == "ubuntu" ]]; then
    # Per https://kubernetes.io/docs/setup/independent/install-kubeadm/
    log "Install latest docker.ce"
    # Per https://docs.docker.com/install/linux/docker-ce/ubuntu/
    wait_dpkg
    if [[ $(sudo apt-get purge -y docker-ce docker docker-engine docker.io) ]]; then
      echo "Purged docker-ce docker docker-engine docker.io"
    fi
    if [[ -e /etc/docker/daemon.json ]]; then
      sudo rm /etc/docker/daemon.json
    fi
    wait_dpkg; sudo apt-get update
    wait_dpkg; sudo apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    wait_dpkg; sudo apt-get update
    apt-cache madison docker-ce
    wait_dpkg; sudo apt-get install -y docker-ce=18.06.3~ce~3-0~ubuntu
  elif [[ "$HOST_OS" == "centos" ]]; then
    log "Install latest docker-ce in Centos"
    # per https://docs.docker.com/engine/installation/linux/docker-ce/centos/#install-from-a-package
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2
    sudo yum-config-manager --add-repo \
      https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce
    sudo systemctl enable docker
    sudo systemctl start docker
  else
    fail "Unsupported host OS: $HOST_OS"
  fi

  log "Install latest docker-compose v3.2"
  # Required, to use docker compose version 3.2 templates
  # Per https://docs.docker.com/compose/install/#install-compose
  # Current version is listed at https://github.com/docker/compose/releases
  sudo curl -L -o /usr/local/bin/docker-compose \
    "https://github.com/docker/compose/releases/download/1.23.1/docker-compose-$(uname -s)-$(uname -m)"
  sudo chmod +x /usr/local/bin/docker-compose
}

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
export AIO_ROOT="$(cd ../AIO; pwd -P)"
source $AIO_ROOT/utils.sh
verify_ubuntu_or_centos
setup
cd $WORK_DIR
