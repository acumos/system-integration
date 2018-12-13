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
# What this is: script to create a subscription for all published models
#
# Prerequisites:
# - see peer-test.sh
#
# Usage:
#   Intended to be called from peer-test.sh, but can be called directly:
#   $ bash create-subscription.sh <host1> <user1> <host2> <user2>
#   host1: Host/domain name of Acumos platform 1
#   user1: Username on host used to deploy Acumos platform 1
#   host2: Host/domain name of Acumos platform 2
#   user2: Username on host used to deploy Acumos platform 2

function fail() {
  log "$1"
  exit 1
}

function log() {
  set +x
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  echo; echo "$fname:$fline ($(date)) $1"
  set -x
}

function find_user() {
  log "Finding user name $1"
  curl -s -o /tmp/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD \
    --header 'Accept: application/json' \
    http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/user
  users=$(jq -r '.content | length' /tmp/json)
  i=0; userId=""
  trap - ERR
  while [[ $i -lt $users && "$userId" == "" ]] ; do
    loginName=$(jq -r ".content[$i].loginName" /tmp/json)
    if [[ "$loginName" == "$1" ]]; then
      userId=$(jq -r ".content[$i].userId" /tmp/json)
    fi
    ((i++))
    done
    trap 'fail' ERR
}

function find_peer() {
  curl -s -o /tmp/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -X GET \
    --header 'Accept: application/json' \
    http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/peer
  peers=$(jq -r '.content | length' /tmp/json)
  i=0; peerId=""
  trap - ERR
  while [[ $i -lt $peers && "$peerId" == "" ]] ; do
    name=$(jq -r ".content[$i].name" /tmp/json)
    if [[ "$name" == "$1" ]]; then
      peerId=$(jq -r ".content[$i].peerId" /tmp/json)
    fi
    ((i++))
  done
}

function create_subscription() {
  trap 'fail' ERR
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
     $2@$1:/home/$2/AIO/acumos-env.sh $1-env.sh
  sed -i -- "s/ACUMOS_DOMAIN=.*/ACUMOS_DOMAIN=$1/" $1-env.sh
  source $1-env.sh
  find_peer $1 $3
  if [[ "$peerId" == "" ]]; then
    cat /tmp/json
    fail "Peer $3 not found at Acumos platform $1"
  fi
  find_user test
  if [[ "$userId" == "" ]]; then
    cat /tmp/json
    fail "User test not found at Acumos platform $1"
  fi
  cat <<EOF >sub.json
{
"accessType": "PB",
"peerId": "$peerId",
"scopeType": "RF",
"refreshInterval": 5,
"selector": "{ \"modelTypeCode\": \"*\" }",
"userId": "$userId"
}
EOF
  cat sub.json
  curl -s -o /tmp/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -X POST \
  http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/peer/sub \
    -H "accept: */*" -H "Content-Type: application/json" -d @sub.json
  created=$(jq -r '.created' /tmp/json)
  if [[ "$created" == "null" ]]; then
    cat /tmp/json
    fail "Subscription creation failed"
  fi
  log "Subscription created successfully:"
  cat /tmp/json
}

set -x
trap 'fail' ERR
export WORK_DIR=$(pwd)
host1=$1
user1=$2
host2=$3
user2=$2

 log "Create subscriptions for all models between $host1 and $host2"

 create_subscription $host1 $user1 $host2
 create_subscription $host2 $user2 $host1
