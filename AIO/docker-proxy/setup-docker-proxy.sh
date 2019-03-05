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
# - acumos-env.sh customized for this platform, as by oneclick_deploy.sh
#
# Usage: intended to be called from oneclick_deploy.sh
#
# See https://docs.acumos.org/en/latest/submodules/kubernetes-client/docs/deploy-in-private-k8s.html#operations-user-guide
# for more information, e.g. on use of this script for manually-installed
# Acumos platforms


function clean() {
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any existing docker based components for docker-proxy"
    cs=$(docker ps -a | awk '/docker-proxy/{print $1}')
    for c in $cs; do
      docker stop $c
      docker rm $c
    done
  else
    log "Stop any existing k8s based components for docker-proxy"
    if [[ ! -e deploy/docker-proxy-service.yaml ]]; then
      mkdir -p deploy
      cp -r kubernetes/* deploy/.
      replace_env deploy
    fi
    stop_service deploy/docker-proxy-service.yaml
    stop_deployment deploy/docker-proxy-deployment.yaml
  fi
}

setup() {
  trap 'fail' ERR
  log "Update docker-proxy config for building the docker image"
  ACUMOS_DOCKER_PROXY_AUTH=$(echo -n "$ACUMOS_NEXUS_RW_USER:$ACUMOS_NEXUS_RW_USER_PASSWORD" | base64)
  sedi "s~<ACUMOS_DOCKER_PROXY_AUTH>~$ACUMOS_DOCKER_PROXY_AUTH~g" auth/nginx.conf
  sedi "s~<ACUMOS_DOCKER_REGISTRY_HOST>~$ACUMOS_DOCKER_REGISTRY_HOST~g" auth/nginx.conf
  sedi "s~<ACUMOS_DOCKER_MODEL_PORT>~$ACUMOS_DOCKER_MODEL_PORT~g" auth/nginx.conf
  sedi "s~<ACUMOS_DOCKER_PROXY_PORT>~$ACUMOS_DOCKER_PROXY_PORT~g" auth/nginx.conf
  sedi "s~<ACUMOS_DOCKER_PROXY_HOST>~$ACUMOS_DOCKER_PROXY_HOST~g" auth/nginx.conf

  log "Copy the Acumos server cert and key to auth/ for the docker image"
  cp ../certs/$ACUMOS_CERT auth/domain.crt
  cp ../certs/$ACUMOS_CERT_KEY auth/domain.key

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Build the local acumos-docker-proxy image"
    docker build -t acumos-docker-proxy .
    source docker-compose.sh up -d --build --force-recreate
  else
    log "Create kubernetes configmap for docker-proxy"
    # See use in docker-proxy deployment template
    if [[ $($k8s_cmd get configmap -n $ACUMOS_NAMESPACE docker-proxy) ]]; then
      log "Delete existing docker-proxy configmap"
      $k8s_cmd delete configmap -n $ACUMOS_NAMESPACE docker-proxy
    fi
    $k8s_cmd create configmap -n $ACUMOS_NAMESPACE docker-proxy \
      --from-file=auth/nginx.conf,auth/domain.key,auth/domain.crt,auth/acumos_auth.py

    log "Deploy the k8s based components for docker-proxy"
    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    replace_env deploy
    start_service deploy/docker-proxy-service.yaml
    start_deployment deploy/docker-proxy-deployment.yaml
    wait_running docker-proxy $ACUMOS_NAMESPACE
  fi

}

clean
setup
