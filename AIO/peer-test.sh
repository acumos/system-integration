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
# - Two Acumos AIO platforms deployed, with access to the saved environment files
# - Both platforms deployed with certs from the same test CA, or a commercial CA
# - All hostnames/FQDNs specified for peers must be DNS-resolvable on all hosts
#   (entries in /etc/hosts or in an actual DNS server)
# - jq installed on the host where this script is being run
#
# Usage:
#   To peer and test two Acumos platforms:
#   $ bash peer-test.sh <env1> <env2>
#   env1: Path to platform 1 acumos-env.sh
#   env2: Path to platform 2 acumos-env.sh
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

function peer_test() {
  trap 'fail' ERR
  set +x
  source $env1
  set -x
  name1=$ACUMOS_DOMAIN
  peergw1="https://$ACUMOS_DOMAIN:$ACUMOS_FEDERATION_PORT"
  set +x
  source $env2
  set -x
  name2=$ACUMOS_DOMAIN
  peergw2="https://$ACUMOS_DOMAIN:$ACUMOS_FEDERATION_PORT"
  bash create-peer.sh $env1 $name2 "admin@$name2" "$peergw2"
  bash create-peer.sh $env2 $name1 "admin@$name1" "$peergw1"
  bash create-subscription.sh $env1 test $name2 PB FL 1 "CL,DS,DT,PR,RG"
  bash create-subscription.sh $env2 test $name1 PB FL 1 "CL,DS,DT,PR,RG"
}

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
env1=$1
env2=$2
peer_test
echo <<EOF
Peer relationship and subscriptions are setup. Any public marketplace models
should appear in the peer in about a minute.
EOF
