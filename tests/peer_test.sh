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
#. Usage:
#.   To peer and test two Acumos platforms:
#.   $ bash peer_test.sh <env1> <admin1> <cert1> <key1> <env2> <admin2> <cert2> <key2>
#.   env1: Path to platform 1 acumos_env.sh
#.   admin1: Userid of Admin role user on platform 1
#.   cert1: Path to platform 1 client certificate
#.   key1: Path to platform 1 private key
#.   env2: Path to platform 2 acumos_env.sh
#.   admin2: Userid of Admin role user on platform 2
#.   cert2: Path to platform 1 client certificate
#.   key2: Path to platform 1 private key
#

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
  bash create_peer.sh $env1 $name2 "admin@$name2" "$peergw2"
  bash create_peer.sh $env2 $name1 "admin@$name1" "$peergw1"
  bash create_subscription.sh $env1 $admin1 $name2 PB FL 1 $cert1 $key1
  bash create_subscription.sh $env2 $admin2 $name1 PB FL 1 $cert2 $key2
}

set -x
trap 'fail' ERR

if [[ $# -eq 8 ]]; then
  env1=$1
  admin1=$2
  cert1=$3
  key1=$4
  env2=$5
  admin2=$6
  cert2=$7
  key2=$8
  WORK_DIR=$(pwd)
  cd $(dirname "$0")
  peer_test
  echo <<EOF
Peer relationship and subscriptions are setup. Any public marketplace models
should appear in the peer in about a minute.
EOF
else
  grep '#. ' $0 | sed 's/#.//g'
  exit 1
fi
