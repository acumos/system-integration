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
# - cd docker-proxy; bash setup-docker-proxy.sh; cd ..
#
# See https://docs.acumos.org/en/latest/submodules/kubernetes-client/docs/deploy-in-private-k8s.html#operations-user-guide
# for more information, e.g. on use of this script for manually-installed
# Acumos platforms

setup() {
  log "Update docker-proxy config for building the docker image"
  ACUMOS_DOCKER_PROXY_AUTH=$(echo -n "$ACUMOS_RO_USER:$ACUMOS_RO_USER_PASSWORD" | base64)
  sed -i -- "s~<ACUMOS_DOCKER_PROXY_AUTH>~$ACUMOS_DOCKER_PROXY_AUTH~g" auth/nginx.conf
  sed -i -- "s~<ACUMOS_NEXUS_HOST>~$ACUMOS_NEXUS_HOST~g" auth/nginx.conf
  sed -i -- "s~<ACUMOS_DOCKER_MODEL_PORT>~$ACUMOS_DOCKER_MODEL_PORT~g" auth/nginx.conf
  sed -i -- "s~<ACUMOS_DOCKER_PROXY_PORT>~$ACUMOS_DOCKER_PROXY_PORT~g" auth/nginx.conf
  sed -i -- "s~<ACUMOS_DOCKER_PROXY_HOST>~$ACUMOS_DOCKER_PROXY_HOST~g" auth/nginx.conf

  log "Generate auth/nginx.htpasswd for the docker image"
  sudo docker run --rm --entrypoint htpasswd registry:2 \
    -Bbn $ACUMOS_DOCKER_PROXY_USERNAME $ACUMOS_DOCKER_PROXY_PASSWORD > auth/nginx.htpasswd

  log "Copy the Acumos server cert and key to auth/ for the docker image"
  cp /var/$ACUMOS_NAMESPACE/certs/acumos.crt auth/domain.crt
  cp /var/$ACUMOS_NAMESPACE/certs/acumos.key auth/domain.key

  log "Build the local acumos-docker-proxy image"
  sudo docker build -t acumos-docker-proxy .

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    # --build will restart any existing container with any new configuration
    sudo bash docker-compose.sh $AIO_ROOT up -d --build --force-recreate
  else
    log "Stop any existing k8s based components for docker-proxy"
    stop_service deploy/docker-proxy-service.yaml
    stop_deployment deploy/docker-deployment.yaml

    log "Deploy the k8s based components for docker-proxy"
    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    replace_env deploy "ACUMOS_DOCKER_API_PORT ACUMOS_DOMAIN ACUMOS_HOST \
      ACUMOS_NAMESPACE ACUMOS_NEXUS_HOST HTTPS_PROXY HTTP_PROXY \
      ACUMOS_DOCKER_MODEL_PORT"

    start_service deploy/docker-proxy-service.yaml
    start_deployment deploy/docker-proxy-deployment.yaml
  fi

  wait_running docker-proxy
}

source $AIO_ROOT/acumos-env.sh
source $AIO_ROOT/utils.sh
setup
