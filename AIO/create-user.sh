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
#.What this is: Utility to create a user via the Acumos common-dataservice API.
#.Prerequisites:
# - Acumos deployed via oneclick_deploy.sh, and acumos-env.sh as updated by it
#.Usage:
#.$ bash create-user.sh <username> <password> <firstName> <lastName> <emailId> [role]
#.  username: username for user
#.  password: password for user
#.  firstName: first name 
#.  lastName: last name
#.  emailId: email address
#.  role: optional role to set for the user (e.g. "admin")
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

function setup_user() {
  trap 'fail' ERR
  log "Create user $username"
  while ! curl -s -o /tmp/json -X POST \
    http://$ACUMOS_PORTAL_FE_HOST:$ACUMOS_PORTAL_FE_PORT/api/users/register \
    -H "Content-Type: application/json" \
    -d "{\"request_body\":{ \"firstName\":\"$firstName\", 
         \"lastName\":\"$lastName\", \"emailId\":\"$emailId\", 
         \"username\":\"$username\", \"password\":\"$password\", 
         \"active\":true}}" ; do
    log "Portal user registration API is not yet active, waiting 10 seconds"
    sleep 10
  done
  error_code=$(jq -r '.error_code' /tmp/json)
  if [[ $error_code -ne 100 ]]; then
    cat /tmp/json
    fail "User account creation failed, error_code $error_code"
  fi
  echo "Portal user account $username created"

  if [[ "$role" != "" ]]; then
    log "Assigning role name $role"
    curl -s -o /tmp/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD \
      http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/role
    roles=$(jq -r '.content | length' /tmp/json)
    i=0; roleId=""
    trap - ERR
    while [[ $i -lt $roles && "$roleId" == "" ]] ; do
      name=$(jq -r ".content[$i].name" /tmp/json)
      if [[ "$name" == "$role" ]]; then
        roleId=$(jq -r ".content[$i].roleId" /tmp/json)
      fi
      ((i++))
    done
    trap 'fail' ERR
    if [[ "$roleId" == "" ]]; then
      log "Create role $role"
      curl -s -o /tmp/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -X POST \
        http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/role \
        -H "accept: */*" -H "Content-Type: application/json" \
        -d "{\"name\": \"$role\", \"active\": true}"
      created=$(jq -r '.created' /tmp/json)
      if [[ "$created" == "null" ]]; then
        cat /tmp/json
        fail "Role creation failed"
      fi
      roleId=$(jq -r '.roleId' /tmp/json)
    fi
    log "Assign role name $role to user $username"
    curl -s -o /tmp/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD \
      http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/user
    users=$(jq -r '.content | length' /tmp/json)
    i=0; userId=""
    trap - ERR
    while [[ $i -lt $users && "$userId" == "" ]] ; do
      loginName=$(jq -r ".content[$i].loginName" /tmp/json)
      if [[ "$loginName" == "$username" ]]; then
        userId=$(jq -r ".content[$i].userId" /tmp/json)
      fi
      ((i++))
    done
    trap 'fail' ERR
    curl -s -o /tmp/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -X POST \
      http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/user/$userId/role/$roleId
    status=$(jq -r '.status' /tmp/json)
    if [[ $status -ne 200 ]]; then
      cat /tmp/json
      fail "Role assignment failed, status $status"
    fi
  fi
  log "Resulting user account record"
  curl -s -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/user/$userId
}

source acumos-env.sh

if [[ $# -ge 5 ]]; then
  username=$1
  password=$2
  firstName=$3
  lastName=$4
  emailId=$5
  role=$6
  setup_user
  log "User creation is complete"
else
  grep '#. ' $0 | sed -i -- 's/#.//g'
fi
