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
# What this is: Utility to create a user via the Acumos common-dataservice API.
#  Used by peer_test.sh to create an admin user for federation setup etc. Also
#  useful to automate creation of test users for various test cases. To assign
#  an additional role to a user, simply call the script with the same parameters
#  but a different role.
#
# Prerequisites:
# - Acumos deployed via oneclick_deploy.sh, and acumos_env.sh as updated by it
#
#. Usage:
#. $ cd system-integration/tests
#. $ bash create_user.sh <env> <username> <password> <firstName> <lastName> <emailId> [role]
#.   env: path to local platform environment file acumos_env.sh
#.   username: username for user
#.   password: password for user
#.   firstName: first name
#.   lastName: last name
#.   emailId: email address
#.   role: optional role to set for the user (e.g. "Admin")
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
  trap 'fail' ERR
  log "Find user $1"
  local tmp="/tmp/$(uuidgen)"
  curl -s -o $tmp -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD \
    $cds_baseurl/user
  cat $tmp
  users=$(jq '.content | length' $tmp)
  i=0; userId=""
  while [[ $i -lt $users && "$userId" == "" ]] ; do
    if [[ "$(jq -r ".content[$i].loginName" $tmp)" == "$1" ]]; then
      userId=$(jq -r ".content[$i].userId" $tmp)
    fi
    i=$((i+1))
  done
  rm $tmp
}

function register_user() {
  trap 'fail' ERR
  local jsoninp="/tmp/$(uuidgen)"
  cat <<EOF >$jsoninp
{
"request_body": {
  "firstName":"$firstName",
  "lastName":"$lastName",
  "emailId":"$emailId",
  "username":"$username",
  "password":"$password",
  "active":true
  }
}
EOF
  cat $jsoninp
  local jsonout="/tmp/$(uuidgen)"
  local apiurl="-k https://$ACUMOS_ORIGIN/api/users/register"
  check_name_resolves portal-fe-service
  if [[ "$NAME_RESOLVES" == "true" ]]; then
    apiurl="http://portal-fe-service:8085/api/users/register"
  fi
  curl -s -o $jsonout -X POST $apiurl \
    -H "Content-Type: application/json" -d @$jsoninp
  cat $jsonout
  t=0
  while [[ "$(jq -r '.response_detail' $jsonout)" != "Success" ]]; do
    sleep 10
    t=$((t+10))
    if [[ $t -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      rm $jsoninp $jsonout
      fail "Unable to register user after $ACUMOS_SUCCESS_WAIT_TIME seconds"
    fi
    curl -s -o $jsonout -X POST $apiurl \
      -H "Content-Type: application/json" -d @$jsoninp
  done
  rm $jsonout $jsoninp
}

function find_role() {
  trap 'fail' ERR
  local tmp="/tmp/$(uuidgen)"
  log "Finding role name $1"
  curl -s -o $tmp -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD \
    $cds_baseurl/role
  cat $tmp
  roles=$(jq '.content | length' $tmp)
  i=0; roleId=""
  while [[ $i -lt $roles && "$roleId" == "" ]] ; do
    name=$(jq -r ".content[$i].name" $tmp)
    if [[ "$name" == "$1" ]]; then
      roleId=$(jq -r ".content[$i].roleId" $tmp)
    fi
    i=$((i+1))
  done
  rm $tmp
}

function create_role() {
  trap 'fail' ERR
  log "Create role name $1"
  local tmp="/tmp/$(uuidgen)"
  curl -s -o $tmp -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -X POST \
  $cds_baseurl/role \
    -H "accept: */*" -H "Content-Type: application/json" \
    -d "{\"name\": \"$1\", \"active\": true}"
  cat $tmp
  created=$(jq -r '.created' $tmp)
  if [[ "$created" == "null" ]]; then
    fail "Role $1 creation failed"
  fi
  roleId=$(jq -r '.roleId' $tmp)
  log "Role name $1 created with roleId=$roleId"
  rm $tmp
}

function assign_role() {
  trap 'fail' ERR
  log "Assign roleId $2 to userId $1"
  local tmp="/tmp/$(uuidgen)"
  curl -s -o $tmp -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -X POST \
    $cds_baseurl/user/$1/role/$2
  status=$(jq -r '.status' $tmp)
  if [[ $status -ne 200 ]]; then
    cat $tmp
    fail "Role assignment failed, status $status"
  fi
  rm $tmp
}

function setup_user() {
  trap 'fail' ERR
  find_user $username
  if [[ "$userId" == "" ]]; then
    log "Create user $username"
    register_user
    find_user $username
    log "Portal user $username created with userId=$userId"
  else
    log "Portal user $username already exists with userId=$userId"
  fi

  if [[ "$role" != "" ]]; then
    find_role $role
    if [[ "$roleId" == "" ]]; then
      create_role $role
    fi
    assign_role $userId $roleId
  fi
  log "Resulting user account record"
  curl -s -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD \
    $cds_baseurl/user/$userId
}

set -x
trap 'fail' ERR

if [[ $# -ge 6 ]]; then
  env=$1
  username=$2
  password=$3
  firstName=$4
  lastName=$5
  emailId=$6
  role=$7
  WORK_DIR=$(pwd)
  cd $(dirname "$0")
  export AIO_ROOT="$(cd ../AIO; pwd -P)"
  source $AIO_ROOT/utils.sh
  source $env
  cds_baseurl="-k https://$ACUMOS_DOMAIN/ccds"
  check_name_resolves cds-service
  if [[ "$NAME_RESOLVES" == "true" ]]; then
    cds_baseurl="http://cds-service:8000/ccds"
  fi
  setup_user
  log "User creation is complete"
  cd $WORK_DIR
else
  grep '#. ' $0 | sed 's/#.//g'
fi
