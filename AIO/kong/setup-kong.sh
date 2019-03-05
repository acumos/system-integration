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
#. What this is: script to setup the kong proxy for Acumos, under docker or k8s
#.
#. Prerequisites:
#. - Acumos core components through oneclick_deploy.sh
#.
#. Usage: intended to be called directly from oneclick_deploy.sh
#.

function clean() {
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any existing docker based components for kong-service"
    cs=$(docker ps -a | awk '/kong/{print $1}')
    for c in $cs; do
      docker stop $c
      docker rm $c
    done
  else
    log "Stop any existing k8s based components for kong-service"
    stop_service deploy/kong-service.yaml
    stop_deployment deploy/kong-deployment.yaml
    log "Remove PVC for kong-service"
    source ../setup-pv.sh clean pvc kong-db $ACUMOS_NAMESPACE
  fi
}

function setup() {
  trap 'fail' ERR
  if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then clean; fi

  log "Start kong-service components"
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    source docker-compose.sh up -d --build --force-recreate
  else
    log "Setup the kong-db PVC"
    source ../setup-pv.sh setup pvc kong-db \
      $ACUMOS_NAMESPACE $KONG_DB_PV_SIZE "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"

    log "Deploy the k8s based components for kong"
    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    replace_env deploy
    start_service deploy/kong-service.yaml
    start_deployment deploy/kong-deployment.yaml
  fi

  wait_running kong

  log "Verify kong admin API is ready"
  url=http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/apis
  while ! curl $url ; do
    log "Kong admin API is not responding... waiting 10 seconds"
    sleep 10
  done
  until [[ $(curl $url | jq -r '.total') -ge 0 ]]; do
    log "Kong admin API is not ready... waiting 10 seconds"
    sleep 10
  done

  log "Pass cert and key to Kong admin"
  curl -i -X POST http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/certificates \
    -F "cert=@$AIO_ROOT/certs/$ACUMOS_CERT" \
    -F "key=@$AIO_ROOT/certs/$ACUMOS_CERT_KEY" \
    -F "snis=$ACUMOS_DOMAIN"

  log "Add proxy entries via Kong API"
  curl -i -X POST \
    --url http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/apis/ \
    --data "https_only=true" \
    --data "name=root" \
    --data "upstream_url=http://portal-fe-service:$ACUMOS_PORTAL_FE_PORT" \
    --data "uris=/" \
    --data "strip_uri=false" \
    --data "upstream_connect_timeout=60000" \
    --data "upstream_read_timeout=60000" \
    --data "upstream_send_timeout=60000" \
    --data "retries=5"

  curl -i -X POST \
    --url http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/apis/ \
    --data "https_only=true" \
    --data "name=onboarding-app" \
    --data "upstream_url=http://onboarding-service:$ACUMOS_ONBOARDING_PORT" \
    --data "uris=/onboarding-app" \
    --data "strip_uri=false" \
    --data "upstream_connect_timeout=60000" \
    --data "upstream_read_timeout=600000" \
    --data "upstream_send_timeout=600000" \
    --data "retries=5"

  log "Dump of API endpoints as created"
  curl http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/apis/
}

setup
