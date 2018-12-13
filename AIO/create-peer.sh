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
#.$ bash create-peer.sh <CAcert> <name> <ip> <subjectName> <contact> <apiUrl>
#.  CAcert: CA certificate to add to truststore /var/$ACUMOS_NAMESPACE/certs/acumosTrustStore.jks
#.  name: hostname to assign to this peer
#.  ip: IP address of hostname
#.  subjectName: subjectName (FQDN) from the cert
#.  contact: admin email address
#.  apiUrl: URL where the peer's federation gateway can be reached
#

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
    -keystore /var/$ACUMOS_NAMESPACE/certs/acumosTrustStore.jks -storepass $ACUMOS_KEYPASS -noprompt

  log "Create peer relationship for $name via CDS API"
  curl -s -o /tmp/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -X POST http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/peer -H "accept: */*" -H "Content-Type: application/json" -d "{ \"name\":\"$name\", \"self\": false, \"local\": false, \"contact1\": \"$contact\", \"subjectName\": \"$subjectName\", \"apiUrl\": \"$apiUrl\",   \"statusCode\": \"AC\", \"validationStatusCode\": \"PS\" }"
  created=$(jq -r '.created' /tmp/json)
  if [[ "$created" == "null" ]]; then
    cat /tmp/json
    fail "Peer creation failed"
  fi
  peerId=$(jq -r '.peerId' /tmp/json)

  log "Add hostalias for $subjectName at $ip and restart federation to apply new truststore entry"
  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    log "Save updated federation-deployment.yaml template for use in redeployment"
    # NOTE: hostAliases must be the last section of federation-deployment.yaml
    # and indented as below
    cat <<EOF >>kubernetes/deployment/federation-deployment.yaml
      - ip: "$ip"
        hostnames:
        - "$subjectName"
EOF
    log "Patch the running federation service, to restart it with the changes"
    cat <<EOF >/tmp/patch.yaml
spec:
  template:
    spec:
      hostAliases:
      - ip: "$ip"
        hostnames:
        - "$subjectName"
EOF
    kubectl patch deployment -n $ACUMOS_NAMESPACE federation \
      --patch "$(cat /tmp/patch.yaml)"
    log "Wait for federation deployment to be terminated and restarted as new pod"
    newpod=$pod
    while [[ $pod == $newpod ]] ; do
      line=$(kubectl get pods -n $ACUMOS_NAMESPACE | awk '/federation/')
      newpod=$(echo $line | awk '{print $1}')
      status=$(echo $line | awk '{print $3}')
      log "Federation pod $newpod is $status"
      sleep 5
    done
  else
    sed -i -- "/extra_hosts:/a\ \ \ \ \ \ \ \ \ \ \ - \"$subjectName:$ip\"" \
      docker/acumos/federation.yml
    sudo bash docker-compose.sh up -d --build federation-service
  fi

  log "Verify federation API is accessible"
  while ! curl -vk --cert /var/$ACUMOS_NAMESPACE/certs/acumos.crt \
  --key /var/$ACUMOS_NAMESPACE/certs/acumos.key \
  https://$ACUMOS_FEDERATION_HOST:$ACUMOS_FEDERATION_PORT/solutions ; do
    log "federation API is not yet accessible. Waiting 10 seconds"
    sleep 10
  done
}

set -x
trap 'fail' ERR
source acumos-env.sh
source utils.sh

CAcert=$1
name=$2
ip=$3
subjectName=$4
contact=$5
apiUrl=$6

setup_peer
# TODO: This is a workaround for non-DNS-resolvable names. For tenant-based
# deploys (no ability to modify hosts file) a different approach is needed.
if [[ $(grep -c -P " $name( |$)" /etc/hosts) -eq 0 ]]; then
  log "Add $name to /etc/hosts"
  echo "$ip $name" | sudo tee -a /etc/hosts
  fi
#setup_subscription
# (to be uncommented once subscription has been verified)
