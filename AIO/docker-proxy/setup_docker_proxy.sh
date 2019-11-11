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
# - acumos_env.sh customized for this platform, as by oneclick_deploy.sh
#
# Usage:
# For docker-based deployments, run this script on the AIO host.
# For k8s-based deployment, run this script on the AIO host or a workstation
# connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
# $ bash setup_docker_proxy.sh
#

function clean_docker_proxy() {
  trap 'fail' ERR
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

update_nginx_auth() {
  trap 'fail' ERR
  log "Update docker-proxy auth config for nginx"
  ACUMOS_DOCKER_PROXY_AUTH=$(echo -n "$ACUMOS_NEXUS_RW_USER:$ACUMOS_NEXUS_RW_USER_PASSWORD" | base64)
  sedi "s~<ACUMOS_DOCKER_PROXY_AUTH>~$ACUMOS_DOCKER_PROXY_AUTH~g" auth/nginx.conf
  sedi "s~<ACUMOS_DOCKER_REGISTRY_HOST>~$ACUMOS_DOCKER_REGISTRY_HOST~g" auth/nginx.conf
  sedi "s~<ACUMOS_DOCKER_MODEL_PORT>~$ACUMOS_DOCKER_MODEL_PORT~g" auth/nginx.conf
  sedi "s~<ACUMOS_DOCKER_PROXY_PORT>~$ACUMOS_DOCKER_PROXY_PORT~g" auth/nginx.conf
  sedi "s~<ACUMOS_DOCKER_PROXY_HOST>~$ACUMOS_DOCKER_PROXY_HOST~g" auth/nginx.conf

  log "Copy the Acumos server cert and key for nginx"
  cp ../certs/$ACUMOS_CERT auth/domain.crt
  cp ../certs/$ACUMOS_CERT_KEY auth/domain.key
}

setup_docker_proxy() {
  trap 'fail' ERR

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    update_nginx_auth
    log "Build the local acumos-docker-proxy image"
    docker build -t acumos-docker-proxy .
    bash docker_compose.sh up -d --build --force-recreate
  else
    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    log "Update the docker-proxy-service template and deploy the service"
    replace_env deploy/docker-proxy-service.yaml
    start_service deploy/docker-proxy-service.yaml
    ACUMOS_DOCKER_PROXY_PORT=$(kubectl get services -n $ACUMOS_NAMESPACE docker-proxy-service -o json | jq -r '.spec.ports[0].nodePort')
    update_acumos_env ACUMOS_DOCKER_PROXY_PORT $ACUMOS_DOCKER_PROXY_PORT force
    update_nginx_auth

    log "Create kubernetes configmap for docker-proxy"
    # See use in docker-proxy deployment template
    if [[ $(kubectl get configmap -n $ACUMOS_NAMESPACE docker-proxy) ]]; then
      log "Delete existing docker-proxy configmap"
      kubectl delete configmap -n $ACUMOS_NAMESPACE docker-proxy
    fi
    kubectl create configmap -n $ACUMOS_NAMESPACE docker-proxy \
      --from-file=auth/nginx.conf,auth/domain.key,auth/domain.crt,auth/acumos_auth.py

    log "Update the docker-proxy deployment template and deploy it"
    replace_env deploy/docker-proxy-deployment.yaml
    get_host_ip_from_etc_hosts $ACUMOS_DOCKER_PROXY_HOST
    if [[ "$HOST_IP" != "" ]]; then
      patch_template_with_host_alias deploy/docker-proxy-deployment.yaml $ACUMOS_DOCKER_PROXY_HOST $HOST_IP
    fi
    start_deployment deploy/docker-proxy-deployment.yaml
    wait_running docker-proxy $ACUMOS_NAMESPACE
  fi
}

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ..; pwd -P)"; fi
source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh
clean_docker_proxy
setup_docker_proxy
cd $WORK_DIR
