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
# What this is: Deployment script for Acumos docker-proxy based upon nginx per
# https://docs.docker.com/registry/recipes/nginx/#setting-things-up
#
# Prerequisites:
# - Ubuntu Xenial or Centos 7 server
#
# Usage:
# - bash docker-proxy/deploy.sh
#
# See https://docs.acumos.org/en/latest/submodules/kubernetes-client/docs/deploy-in-private-k8s.html#operations-user-guide
# for more information, e.g. on use of this script for manually-installed
# Acumos platforms

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

function wait_dpkg() {
  # TODO: workaround for "E: Could not get lock /var/lib/dpkg/lock - open (11: Resource temporarily unavailable)"
  echo; echo "waiting for dpkg to be unlocked"
  while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
    sleep 1
  done
}

setup_prereqs() {
  wait_dpkg
  if [[ $(dpkg -l | grep -c docker-ce) -eq 0 ]]; then
    log "Install latest docker-ce"
    # Per https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/
    sudo apt-get purge -y docker docker-engine docker.io docker-ce
    sudo apt-get update
    sudo apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce
  fi

  if [[ $(dpkg -l | grep -c docker-compose) -eq 0 ]]; then
    log "Install latest docker-compose"
    sudo apt-get install -y docker-compose
  fi
}

setup_proxy() {
  sudo rm -rf /var/acumos/docker-proxy
  sudo cp -R docker-proxy /var/acumos/.
  sudo chown -R $USER /var/acumos/docker-proxy
  ACUMOS_DOCKER_PROXY_AUTH=$(echo -n "$ACUMOS_RO_USER:$ACUMOS_RO_USER_PASSWORD" | base64)
  sed -i -- "s~<ACUMOS_DOCKER_PROXY_AUTH>~$ACUMOS_DOCKER_PROXY_AUTH~g" /var/acumos/docker-proxy/auth/nginx.conf
  sed -i -- "s~<ACUMOS_NEXUS_HOST>~$ACUMOS_NEXUS_HOST~g" /var/acumos/docker-proxy/auth/nginx.conf
  sed -i -- "s~<ACUMOS_DOCKER_MODEL_PORT>~$ACUMOS_DOCKER_MODEL_PORT~g" /var/acumos/docker-proxy/auth/nginx.conf
  sed -i -- "s~<ACUMOS_DOCKER_PROXY_PORT>~$ACUMOS_DOCKER_PROXY_PORT~g" /var/acumos/docker-proxy/auth/nginx.conf
  sed -i -- "s~<ACUMOS_DOCKER_PROXY_HOST>~$ACUMOS_DOCKER_PROXY_HOST~g" /var/acumos/docker-proxy/auth/nginx.conf
  sudo docker run --rm --entrypoint htpasswd registry:2 -Bbn $ACUMOS_DOCKER_PROXY_USERNAME $ACUMOS_DOCKER_PROXY_PASSWORD > /var/acumos/docker-proxy/auth/nginx.htpasswd
  cp /var/acumos/certs/acumos.crt /var/acumos/docker-proxy/auth/domain.crt
  cp /var/acumos/certs/acumos.key /var/acumos/docker-proxy/auth/domain.key
  sudo bash docker-proxy/docker-compose.sh up -d
}

export WORK_DIR=$(pwd)
source acumos-env.sh
setup_prereqs
setup_proxy
cd $WORK_DIR
