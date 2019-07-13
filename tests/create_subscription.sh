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
# - All hostnames/FQDNs specified for peers must be DNS-resolvable on all hosts
#   (entries in /etc/hosts or in an actual DNS server)
# - jq installed on the host where this script is being run
#
# Usage:
# $ bash create_subscription.sh <env> <admin> <peer> <accessType> <scopeType>
#                               <refreshInterval> <cert> <key>
#   env: path to local platform environment file acumos_env.sh
#   admin: name of Admin role user on the local platform
#   peer: hostname or FQDN and port of the peer platform
#   accessType: PB|OR|PR (public|company|private)
#   scopeType: RF|FL (RF: references only | FL: all data)
#   refreshInterval: time in minutes
#   cert: client certificate for the local platform
#   key: private key for the local platform
#
# See the "Common Data Service Requirements" for details on the codes above
#
# To cleanup all subscriptions:
# i=0; while [[ $(curl -k -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -X DELETE https://$ACUMOS_ORIGIN/ccds/peer/sub/$i | jq -r '.status') != 400 ]]; do i=$((i+1)); done

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

function find_user() {
  trap 'fail' ERR
  log "Finding user name $admin"
  local jsonout="/tmp/$(uuidgen)"
  curl -s -k -o $jsonout -u $creds -H 'Accept: application/json' $cds/user
  users=$(jq -r '.content | length' $jsonout)
  i=0; userId=""
  while [[ $i -lt $users && "$userId" == "" ]] ; do
    loginName=$(jq -r ".content[$i].loginName" $jsonout)
    if [[ "$loginName" == "$admin" ]]; then
      userId=$(jq -r ".content[$i].userId" $jsonout)
    fi
    i=$((i+1))
  done
  cat $jsonout
  rm $jsonout
}

function find_peer() {
  trap 'fail' ERR
  local jsonout="/tmp/$(uuidgen)"
  curl -s -k -o $jsonout -u $creds -H 'Accept: application/json' $cds/peer
  peers=$(jq -r '.content | length' $jsonout)
  i=0; peerId=""
  while [[ $i -lt $peers && "$peerId" == "" ]] ; do
    name=$(jq -r ".content[$i].name" $jsonout)
    if [[ "$name" == "$peer" ]]; then
      peerId=$(jq -r ".content[$i].peerId" $jsonout)
    fi
    i=$((i+1))
  done
  cat $jsonout
  rm $jsonout
}

function create_subscription() {
  trap 'fail' ERR
  local jsonout="/tmp/$(uuidgen)"
  curl -v -k -o $jsonout --cert $cert --key $key https://$peer:${peerPort}/catalogs
  cats=$(jq -r '.content | length' $jsonout)
  log DEBUG "$cats catalogs found: "
  cat $jsonout
  j=0
  atc=""
  while [[ $j -le $cats && "$atc" != "$accessType" ]] ; do
    cid=$(jq -r ".content[$j].catalogId" $jsonout)
    atc=$(jq -r ".content[$j].accessTypeCode" $jsonout)
    j=$((j+1))
  done
  rm $jsonout
  if [[ $j -gt $cats ]]; then
    fail "Access type $accessType not found in catalogs"
  fi

  local jsonin="/tmp/$(uuidgen)"
  cat <<EOF >$jsonin
{
"peerId": "$peerId",
"refreshInterval": $refreshInterval,
"selector": "{ \"catalogId\": \"$cid\" }",
"userId": "$userId"
}
EOF
  cat $jsonin
  local jsonout="/tmp/$(uuidgen)"
  curl -s -k -o $jsonout -u $creds -X POST $cds/peer/sub \
    -H "accept: */*" -H "Content-Type: application/json" -d @$jsonin
  rm $jsonin
  created=$(jq -r '.created' $jsonout)
  cat $jsonout
  rm $jsonout
  if [[ "$created" == "null" ]]; then
    fail "Subscription creation failed"
  fi
  log "Subscription created successfully:"
  log "Current subscriptions at $ACUMOS_DOMAIN for peer $peer with ID $peerId"
  curl -k -u $creds -H 'Accept: application/json' $cds/peer/$peerId/sub
}

set -x
if [[ $# -lt 8 ]]; then
  cat <<'EOF'
Usage:
  $ bash create_subscription.sh <env> <admin> <peer> <accessType> <scopeType>
                                <refreshInterval> <cert> <key>
    env: path to local platform environment file acumos_env.sh
    admin: name of Admin role user on the local platform
    peer: hostname or FQDN and port of the peer Federation service
    accessType: PB|OR|PR (public|company|private)
    scopeType: RF|FL (RF: references only | FL: all data)
    refreshInterval: time in minutes
    cert: client certificate for the local platform
    key: private key for the local platform
EOF
  echo "All parameters not provided"
  exit 1
fi

set -x
export WORK_DIR=$(pwd)
env=$1
admin=$2
peer=$(echo $3 | cut -d ':' -f 1)
peerPort=$(echo $3 | cut -d ':' -f 2)
accessType=$4
scopeType=$5
refreshInterval=$6
cert=$7
key=$8
set +x
source $env
set -x
cds="https://$ACUMOS_ORIGIN/ccds"
creds="$ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD"
find_peer
if [[ "$peerId" == "" ]]; then
  fail "Peer $peer not found at Acumos platform $ACUMOS_DOMAIN"
fi
find_user
if [[ "$userId" == "" ]]; then
  fail "User $admin not found at Acumos platform $ACUMOS_DOMAIN"
fi
log "Create subscriptions for all models between $ACUMOS_DOMAIN and $peer"
create_subscription
