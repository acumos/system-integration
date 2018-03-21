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
#
# Usage:
# $ bash peer-test.sh <host1> <user1> <host2> <user2> <bootstrap>
#   host1: AIO deploy target hostname
#   user1: user account on host1
#   host2: AIO deploy target hostname
#   user2: user account on host2
#   bootstrap: folder for bootstrap.sh script and models
#

set -x

trap 'fail' ERR

function fail() {
  log "$1"
  exit 1
}

function log() {
  f=$(caller 0 | awk '{print $2}')
  l=$(caller 0 | awk '{print $1}')
  echo; echo "$f:$l ($(date)) $1"
}

function deploy() {
  trap 'fail' ERR
  log "Deploying Acumos AIO to $1 user $2"
  scp -r -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    * $2@$1:/home/$2/.
  scp -r -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    $3 $2@$1:/home/$2/.
  ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    $2@$1 <<EOF
trap 'exit 1' ERR
bash clean.sh
bash oneclick_deploy.sh 2>&1 | tee deploy.log
bash create-user.sh test P@ssw0rd! test user test@acumos-aio.com admin
EOF
}

source acumos-env.sh

host1=$1
user1=$2
host2=$3
user2=$4
bootstrap=$5

deploy $host1 $user1 $bootstrap
deploy $host2 $user2 $bootstrap

log "Exchange peer CA certs and server certs"
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  $user1@$host1:/home/$user1/certs/acumosCA.crt /tmp/${host1}CA.crt
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  $user2@$host2:/home/$user2/certs/acumosCA.crt /tmp/${host2}CA.crt
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  /tmp/${host1}CA.crt $user2@$host2:/home/$user2/certs/peerCA.crt
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  /tmp/${host2}CA.crt $user1@$host1:/home/$user1/certs/peerCA.crt

log "Create $host2 peer at $host1"
ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  $user1@$host1 <<EOF
source acumos-env.sh
bash create-peer.sh certs/peerCA.crt $host2 $host2 admin@example.com \
  https://$host2:$ACUMOS_FEDERATION_PORT
EOF

log "Create $host1 peer at $host2"
ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  $user2@$host2 <<EOF
source acumos-env.sh
bash create-peer.sh certs/peerCA.crt $host1 $host1 admin@example.com \
  https://$host1:$ACUMOS_FEDERATION_PORT
EOF

#curl -vk --cert certs/acumos.crt --key certs/acumos.key https://$host1:9084/solutions

log "Bootstrap models at $host1"
ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  $user1@$host1 <<EOF
cd bootstrap
bash bootstrap.sh
EOF

log "Bootstrap models at $host2"
ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  $user2@$host2 <<EOF
cd bootstrap
bash bootstrap.sh
EOF

echo <<EOF
Deployment is complete at $host1 and $host2. Sample models have been onboarded
to $host1 for user 'test'. To complete the test, 
1) Manually complete Hippo CMS setup at $host1 and $host2:
   a) Login at https://$host1:$ACUMOS_CMS_PORTcms/console/?0 as "admin:admin"
   b) Select "hts:hst" then "hst:hosts" then "dev-env"
   c) Click child element under "dev-env" until you see acumos-dev1-vm01-core
   d) Right-click acumos-dev1-vm01-core and select "move", select "dev-env" as
      the move destination, and change the target name to $host1 , then 'ok'
   e) On the upper right select "Write changes to repository" then 'ok'
2) Repeat (1) for $host2
3) login to $host1 as user 'test' with password 'P@ssw0rd!', and manually 
   complete the model publication process to the Public Marketplace
4) Repeat (3) for $host2
EOF
