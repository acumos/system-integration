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
#.What this is: Utility to create an Acumos portal peer relationship via the
#.  Acumos common-dataservice API.
#.Prerequisites:
# - Acumos deployed via oneclick_deploy.sh, and acumos-env.sh as updated by it
# - All FQDNs specified for peers must be DNS-resolvable on all hosts
#   (entries in /etc/hosts or in an actual DNS server)
#.Usage:
#.$ bash create-peer.sh <CAcert> <name> <subjectName> <contact> <apiUrl>
#.  CAcert: CA certificate to add to truststore ~/certs/acumosTrustStore.jks
#.  name: name to assign to this peer
#.  subjectName: subjectName (FQDN) from the cert
#.  contact: admin email address
#.  apiUrl: URL where the peer's federation gateway can be reached
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

function setup_subscription() {
  trap 'fail' ERR
  log "Get userId of 'test' user"
  curl -s -o /tmp/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD \
    http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/user
  users=$(jq -r '.content | length' /tmp/json)
  i=0; userId=""
  while [[ $i -lt $users && "$userId" == "" ]] ; do
    loginName=$(jq -r ".content[$i].loginName" /tmp/json)
    if [[ "$loginName" == "test" ]]; then
      userId=$(jq -r ".content[$i].userId" /tmp/json)
    fi
    ((i++))
  done

  log "Subscribe to all solution types at $peerId"
  curl -s -o /tmp/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -X POST http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/peer/sub -H "accept: */*" -H "Content-Type: application/json" -d "{ \"peerId\":\"$peerId\", \"ownerId\":\"$userId\", \"scopeType\":\"FL\", \"accessType\":\"PB\", \"options\":null, \"refreshInterval\":3600, \"maxArtifactSize\":null}"
}

function setup_peer() {
  trap 'fail' ERR
  log "Import peer CA cert into truststore"
  keytool -import -file $CAcert -alias ${subjectName}CA \
    -keystore certs/acumosTrustStore.jks -storepass $ACUMOS_KEYPASS -noprompt

  log "Create peer relationship for $name via CDS API"
  curl -s -o /tmp/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -X POST http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/peer -H "accept: */*" -H "Content-Type: application/json" -d "{ \"name\":\"$name\", \"self\": false, \"local\": false, \"contact1\": \"$contact\", \"subjectName\": \"$subjectName\", \"apiUrl\": \"$apiUrl\",   \"statusCode\": \"AC\", \"validationStatusCode\": \"PS\" }"
  created=$(jq -r '.created' /tmp/json)
  if [[ "$created" == "null" ]]; then
    cat /tmp/json
    fail "Peer creation failed"
  fi
  peerId=$(jq -r '.peerId' /tmp/json)

  log "Add hosts file entry for peer to support non-DNS resolvable hostnames"
  # TODO: find a way to setup these names in DNS, or if this is a longer term
  # workaround a way to use docker-compose.sh for this (tests of this command
  # with docker-compose.sh have not been successful)
  ip=$(host $subjectName | awk '{print $4}')
  sudo docker exec $USER_federation-gateway_1 \
    /bin/sh -c "echo $ip $subjectName >>/etc/hosts"

  log "Restart federation-gateway to apply new truststore entry"
  sudo bash docker-compose.sh restart federation-gateway

  log "Verify federation API is accessible"
  while ! curl -vk --cert certs/acumos.crt --key certs/acumos.key \
  https://$ACUMOS_FEDERATION_HOST:$ACUMOS_FEDERATION_PORT/solutions ; do
    log "federation API is not yet accessible. Waiting 10 seconds"
    sleep 10
  done
}

source acumos-env.sh

CAcert=$1
name=$2
subjectName=$3
contact=$4
apiUrl=$5

setup_peer
#setup_subscription
# (to be uncommented once subscription has been verified)

