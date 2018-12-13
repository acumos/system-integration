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
# - Acumos deployed via oneclick_deploy.sh, and acumos-env.sh as updated by it
# - key-based SSH access setup for running commands on the two target AIO hosts
# - hostname of host1 and host2 resolvable in DNS or setup in /etc/hosts
# - jq installed on the host
# - For deployment of test models per the [models] option, a python localindex
#   may need to be provided if the models are not packagable into containers
#   by docker based upon the public pypi index. This local index is configured
#   as per PYTHON_EXTRAINDEX and PYTHON_EXTRAINDEX_HOST in acumos-env.sh, and
#   is served by twistd as setup in oneclick_deploy.sh
#
# Usage:
# $ bash peer-test.sh <host1> <ip1> <user1> <host2> <ip2> <user2> [models]
#   host1: AIO deploy target hostname
#   ip1: IP address of host1
#   user1: user account on host1
#   host2: AIO deploy target hostname
#   ip2: IP address of host2
#   user2: user account on host2
#   models: optional folder with models to onboard
#

function clean() {
  trap 'fail' ERR
  log "Cleaning Acumos AIO at $1 user $2"
  # Copy latest clean.sh over in case some earlier bug in cleanup needs fixing...
  ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $2@$1 \
    mkdir -p /home/$2/AIO
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no clean.sh \
    $2@$1:/home/$2/AIO/.
  ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $2@$1 <<EOF
set -x
trap 'exit 1' ERR
cd AIO
bash clean.sh
rm -rf *
EOF
}

function deploy() {
  trap 'fail' ERR
  log "Deploying Acumos AIO to $1 user $2"
  scp -r -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    ../AIO $2@$1:/home/$2/.
  # Run the commands separately to ensure failures are trapped
  ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $2@$1 <<EOF
set -x
trap 'exit 1' ERR
cd AIO
bash oneclick_deploy.sh
bash create-user.sh test P@ssw0rd test user test@acumos-aio.com Admin
bash create-user.sh test P@ssw0rd test user test@acumos-aio.com Publisher
EOF
}

function verify_federation_api_access() {
  log "Verify federation API access at $3 for $1"
  ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $2@$1 \
    curl -vk -o json \
    --cert /var/$ACUMOS_NAMESPACE/certs/acumos.crt \
    --key /var/$ACUMOS_NAMESPACE/certs/acumos.key \
    https://$3:$ACUMOS_FEDERATION_PORT/solutions
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    $2@$1:/home/$2/json json
  cat json
  err=$(jq -r '.error' json)
  if [[ "$err" != "null" ]]; then
    fail "Solution retrieval failed"
  fi
}

source acumos-env.sh
source utils.sh
trap 'fail' ERR
set -x
export WORK_DIR=$(pwd)
host1=$1
ip1=$2
user1=$3
host2=$4
ip2=$5
user2=$6
models="$7"

clean $host1 $user1
deploy $host1 $user1
clean $host2 $user2
deploy $host2 $user2

log "Exchange peer CA certs and server certs"
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  $user1@$host1:/var/$ACUMOS_NAMESPACE/certs/acumosCA.crt /tmp/${host1}CA.crt
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  $user2@$host2:/var/$ACUMOS_NAMESPACE/certs/acumosCA.crt /tmp/${host2}CA.crt
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  /tmp/${host1}CA.crt $user2@$host2:/var/$ACUMOS_NAMESPACE/certs/peerCA.crt
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  /tmp/${host2}CA.crt $user1@$host1:/var/$ACUMOS_NAMESPACE/certs/peerCA.crt

log "Create $host2 peer at $host1"
ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  $user1@$host1 <<EOF
set -x
trap 'exit 1' ERR
cd AIO
source acumos-env.sh
bash create-peer.sh /var/$ACUMOS_NAMESPACE/certs/peerCA.crt $host2 $ip2 $host2 \
  admin@example.com https://$host2:$ACUMOS_FEDERATION_PORT
EOF

log "Create $host1 peer at $host2"
ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  $user2@$host2 <<EOF
set -x
trap 'exit 1' ERR
cd AIO
source acumos-env.sh
bash create-peer.sh /var/$ACUMOS_NAMESPACE/certs/peerCA.crt $host1 $ip1 $host1 \
  admin@example.com https://$host1:$ACUMOS_FEDERATION_PORT
EOF

verify_federation_api_access $host1 $user1 $host2
verify_federation_api_access $host2 $user2 $host1

if [[ "$models" != "" ]]; then
  log "Bootstrap models at $host1"
  bash ./bootstrap-models.sh $host1:$ACUMOS_KONG_PROXY_SSL_PORT test P@ssw0rd "$models"

  log "Bootstrap models at $host2"
  bash ./bootstrap-models.sh $host2:$ACUMOS_KONG_PROXY_SSL_PORT test P@ssw0rd "$models"
fi

echo <<EOF
Deployment is complete at $host1 and $host2. Sample models have been onboarded
to $host1 for user 'test'. To complete the test,
1) login to $host1 as user 'test' with password 'P@ssw0rd!', and manually
   complete the model publication process to the Public Marketplace
2) Repeat (1) for $host2
EOF
