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
# What this is: Utility to create an Acumos portal peer relationship via the
#   Acumos common-dataservice API.
# Prerequisites:
# - Acumos AIO platform deployed, with access to the saved environment files
# - Both platforms deployed with certs from the same test CA, or a commercial CA
# - All hostnames/FQDNs specified for peers must be DNS-resolvable on all hosts
#   (entries in /etc/hosts or in an actual DNS server)
# - jq installed on the host where this script is being run
#
# Usage:
# $ bash create_peer.sh <env> <name> <contact> <peergw>
#   env: path to local platform environment file acumos_env.sh
#   peer: hostname or FQDN of the peer platform
#   contact: admin email address of the peer platform
#   peergw: URL where the peer's federation gateway can be reached
#

function fail() {
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

function setup_peer() {
  trap 'fail' ERR
  local cdsapi="https://$ACUMOS_DOMAIN:$ACUMOS_KONG_PROXY_SSL_PORT/ccds/peer"
  local creds="$ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD"
  local peers=$(curl -s -u $creds -k $cdsapi)
  local np=$(echo $peers | jq '.content | length')
  log "$np peers found in database"
  local i=0
  name=$(echo $peers | jq -r ".content[$i].name")
  while [[ "$name" != "$peer" && $i -lt $np ]]; do
    ((++i))
    name=$(echo $peers | jq -r ".content[$i].name")
  done
  if [[ $i -eq $np ]]; then
    local jsonout="/tmp/$(uuidgen)"
    local jsonin="/tmp/$(uuidgen)"
    cat <<EOF >$jsonin
{
"name": "$peer",
"self": false,
"local": false,
"contact1": "$contact",
"subjectName": "$peer",
"apiUrl": "$peergw",
"statusCode": "AC",
"validationStatusCode": "PS"
}
EOF
    log "Create peer relationship for $peer via CDS API"
    cat $jsonin
    curl -s -o $jsonout -u $creds -X POST -k $cdsapi \
      -H "accept: */*" -H "Content-Type: application/json" -d @$jsonin
    created=$(jq -r '.created' $jsonout)
    cat $jsonout
    rm $jsonin $jsonout
    if [[ "$created" == "null" ]]; then
      fail "Peer creation failed"
    fi
  else
    log "$ACUMOS_DOMAIN peer relationship for $peer already exists"
  fi
}

set -x
trap 'fail' ERR

env=$1
peer=$2
contact=$3
peergw=$4

WORK_DIR=$(pwd)
cd $(dirname "$0")
set +x
source $env
set -x
setup_peer
cd $WORK_DIR
