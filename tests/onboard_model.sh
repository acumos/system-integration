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
#. What this is: script to automate model onboarding.
#.
#. Prerequisites:
#. - User has account on Acumos platform
#. - Model dumped by the Acumos client library, i.e. the following files
#.   - metadata.json
#.   - model.proto
#.   - model.zip
#.
#. Usage:
#. $ bash onboard-model.sh <host> <username> <password> <model> <insecure>
#.   host: host of the model onboarding service, including port if needed
#.   username: username to onboard models for
#.   password: password for user
#.   model: folder with model to onboard
#.   insecure: optional flag allowing onboarding to insecure server (installed
#.      with self-signed server cert, as needed for test platforms)

function fail() {
  reason="$1"
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  if [[ "$1" == "" ]]; then reason="unknown failure at $fname $fline"; fi
  log "$reason"
  exit 1
}

function log() {
  setx=${-//[^x]/}
  set +x
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  echo; echo "$fname:$fline ($(date)) $1"
  if [[ -n "$setx" ]]; then set -x; else set +x; fi
}

function onboard() {
  trap 'fail' ERR
  AUTHURL=https://$host/onboarding-app/v2/auth
  PUSHURL=https://$host/onboarding-app/v2/models

  json="/tmp/$(date +%H%M%S%N)"

  log "Query rest service at host $host to get token"
  curl -o $json -k -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' $AUTHURL -d "{\"request_body\":{\"username\":\"$user\",\"password\":\"$pass\"}}"
  if [[ $(grep -c "doctype html" $json) -gt 0 ]]; then
    cat $json
    fail "Authentication failed at host $host"
  fi
  jwtToken=$(jq -r '.jwtToken' $json)
  if [[ "$jwtToken" == "null" ]]; then
    cat $json
    fail "Authentication failed at host $host"
  fi

  # Use the jwtToken for onboarding
  log "Authentication successful"
  echo "Onboarding model $model at $host ..."
  set -x
  proto=$(ls $model/*.proto)
  if [[ "$insecure" == "insecure" ]]; then k="-k"; fi
  if [[ -e $model/license.json ]]; then
    log "Onboarding with license file license.json"
    curl -o $json $k -H "Authorization: $jwtToken" \
         -F "license=@$model/license.json;type=application/json" \
         -F "model=@$model/model.zip;type=application/zip" \
         -F "metadata=@$model/metadata.json;type=application/json" \
         -F "schema=@$proto;type=application/text" $PUSHURL
  else
    curl -o $json $k -H "Authorization: $jwtToken" \
         -F "model=@$model/model.zip;type=application/zip" \
         -F "metadata=@$model/metadata.json;type=application/json" \
         -F "schema=@$proto;type=application/text" $PUSHURL
  fi
  set +x
  if [[ $(grep -c -e "The upstream server is timing out" -e "Service unavailable" $json) -gt 0 ]]; then
    log "Onboarding $model failed at host $host"
    cat $json
  else
    if [[ "$(jq -r '.status' $json)" == "SUCCESS" ]]; then
      log "Onboarding $model succeeded at host $host"
    else
      log "Onboarding $model failed at host $host"
      cat $json
    fi
  fi
}

trap 'fail' ERR
if [[ "$#" -lt 4 ]]; then
  echo "All required parameters not provided"
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then grep '#\.' $0; fi
else
  host=$1
  user=$2
  pass=$3
  model="$4"
  insecure=$5
  onboard
fi
