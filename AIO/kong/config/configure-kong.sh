#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2018-2019 AT&T Intellectual Property. All rights reserved.
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
# What this is: script to configure the kong proxy for Acumos, under docker or
# k8s.
#
# Prerequisites:
# - Acumos core components through oneclick_deploy.sh
#
# Usage: intended to be used from within the configure-kong container, which
# is a short-lived container to initialize or update the kong configuration.
# This approach avoids the need to expose the kong admin API external to the
# Acumos platform.
#

function fail() {
  set +x
  trap - ERR
  reason="$1"
  if [[ "$1" == "" ]]; then reason="unknown failure at $fname $fline"; fi
  log "$reason"
  exit 1
}

function log() {
  set +x
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  echo; echo "$fname:$fline ($(date)) $1"
  set -x
}

function configure() {
  trap 'fail' ERR
  kong_url=http://$KONG_ADMIN_HOST:$KONG_ADMIN_PORT

  log "Verify kong admin API is ready"
  while ! curl -m 10 $kong_url/apis ; do
    log "Kong admin API is not responding..."
    sleep 10
  done
  until [[ $(curl -m 10 $kong_url/apis | jq -r '.total') -ge 0 ]]; do
    log "Kong admin API is not ready... waiting 10 seconds"
    sleep 10
  done

  log "Pass cert and key to Kong admin"
  curl -i -X POST $kong_url/certificates \
    -F "cert=@$ACUMOS_CERT" \
    -F "key=@$ACUMOS_CERT_KEY" \
    -F "snis=$ACUMOS_DOMAIN"

  log "Add proxy entries via Kong API"
  apis=$(ls *.json)
  for api in $apis; do
    name=$(echo $api | cut -d '.' -f 1)
    log "Deleting proxy entry $name"
    curl -X DELETE $kong_url/apis/$name
    log "Creating proxy entry $name"
    curl -X POST -H "Content-type: application/json" -d @$name.json \
      $kong_url/apis/
  done

  log "Dump of API endpoints as created"
  curl $kong_url/apis/
}

cd /var/acumos/config
configure
