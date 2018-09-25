#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2018 AT&T Intellectual Property. All rights reserved.
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
# What this is: test script for deploying two Acumos AIO instances and
#   verifying federation. Deploys Acumos in AIO configuration, uploads models
#   to one AIO instance, federates the two instances, and verifies model sync
#   from host1 to host2.
#
# Prerequisites:
# - Acumos deployed via oneclick_deploy.sh
# - key-based SSH access setup for running commands on the two target AIO hosts
# - hostname of host1 and host2 resolvable in DNS or setup in /etc/hosts
# - jq installed on the host
#
# Usage:
# $ bash bootstrap-models.sh <host> <username> <password> <models>
#   host: host:port of the model onboarding service accesible via HTTPS
#   username: username to onboard models for
#   password: password for user
#   models: optional folder with models to onboard

trap 'fail' ERR

function fail() {
  log "$1"
  cd $WORK_DIR
  exit 1
}

function log() {
  f=$(caller 0 | awk '{print $2}')
  l=$(caller 0 | awk '{print $1}')
  echo; echo "$f:$l ($(date)) $1"
}

function onboard_model() {
  echo "Onboarding model $2 at $host ..."
  proto=$(ls $1/$2/*.proto)
  curl -o ~/json -k -H "Authorization: $jwtToken"\
       -F "model=@$1/$2/model.zip;type=application/zip" \
       -F "metadata=@$1/$2/metadata.json;type=application/json"\
       -F "schema=@$proto;type=application/text" $PUSHURL
  if [[ $(grep -c -e "The upstream server is timing out" -e "Service unavailable" ~/json) -gt 0 ]]; then
    log "Onboarding $2 failed at host $host"
    cat ~/json
  else
    status=$(jq -r '.status' ~/json)
    if [[ "$status" != "ERROR" ]]; then
      log "Onboarding $2 succeeded at host $host"
      # log "Adding image for model $model ..."
      # curl -H "Authorization: $jwtToken" <rest of curl command to upload image for the model from models/$model/image.jpg>
      # log "Adding descriptitive text for model $model ..."
      # curl -H "Authorization: $jwtToken" <rest of curl command to upload description for the model from models/$model/description.txt>
    else
      log "Onboarding $2 failed at host $host"
      cat ~/json
    fi
  fi
}

function bootstrap() {
  trap 'fail' ERR
  AUTHURL=https://$host/onboarding-app/v2/auth
  PUSHURL=https://$host/onboarding-app/v2/models

  log "Query rest service at host $host to get token"
  curl -o ~/json -k -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' $AUTHURL -d "{\"request_body\":{\"username\":\"$user\",\"password\":\"$pass\"}}"
  if [[ $(grep -c "doctype html" ~/json) -gt 0 ]]; then
    cat ~/json
    fail "Authentication failed at host $host"
  fi
  jwtToken=$(jq -r '.jwtToken' ~/json)
  if [[ "$jwtToken" == "null" ]]; then
    cat ~/json
    fail "Authentication failed at hpst $host"
  fi

  # Use this jwtToken for all the bootstrap onboarding
  log "Authentication successful"
  if [[ -f $models_dir/model.zip ]]; then
    model=$(echo $models_dir | grep -o '[^,/]*$')
    dir=$(echo $models_dir | sed -- "s~/$model~~")
    log "Selected $model from $dir"
    onboard_model $dir $model
  else
    models=$(ls $models_dir)
    for model in $models; do
      onboard_model $models_dir $model
    done
  fi
}

host=$1
user=$2
pass=$3
models_dir="$4"
bootstrap
