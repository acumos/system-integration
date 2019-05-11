#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2019 AT&T Intellectual Property. All rights reserved.
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
# What this is: Utility to delete a user via the Acumos common-dataservice API.
#
# Prerequisites:
# - Acumos deployed via oneclick_deploy.sh, and acumos_env.sh as updated by it
#
#. Usage:
#. $ cd system-integration/tests
#. $ bash delete_user.sh <env> <username>
#.   env: path to local platform environment file acumos_env.sh
#.   username: username for user
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

function find_user() {
  log "Find user $1"
  local tmp="/tmp/$(uuidgen)"
  curl -s -o $tmp -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD \
    -k https://$ACUMOS_DOMAIN/ccds/user
  cat $tmp
  users=$(jq -r '.content | length' $tmp)
  i=0; userId=""
  while [[ $i -lt $users && "$userId" == "" ]] ; do
    if [[ "$(jq -r ".content[$i].loginName" $tmp)" == "$1" ]]; then
      userId=$(jq -r ".content[$i].userId" $tmp)
    fi
    i=$((i+1))
  done
  rm $tmp
}

function delete_user() {
  trap 'fail' ERR
  find_user $username
  if [[ "$userId" != "" ]]; then
    log "Delete user $username"
    curl -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -X DELETE \
      -k https://$ACUMOS_DOMAIN/ccds/user/$userId
    find_user $username
    if [[ "$userId" != "" ]]; then
      fail "User delete failed"
    else
      log "User delete succeeded"
    fi
  else
    log "Portal user $username not found"
  fi
}

set -x
trap 'fail' ERR

if [[ $# -eq 2 ]]; then
  env=$1
  username=$2
  WORK_DIR=$(pwd)
  cd $(dirname "$0")
  source $env
  delete_user
  cd $WORK_DIR
else
  grep '#. ' $0 | sed 's/#.//g'
fi
