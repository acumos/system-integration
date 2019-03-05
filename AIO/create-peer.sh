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
# What this is: Utility to create an Acumos portal peer relationship via the
#   Acumos common-dataservice API.
# Prerequisites:
# - Acumos deployed via oneclick_deploy.sh, and acumos-env.sh as updated by it
# - All FQDNs specified for peers must be DNS-resolvable on all hosts
#   (entries in /etc/hosts or in an actual DNS server)
#
# Usage:
# $ bash create-peer.sh <CAcert> <name> <name> <contact> <apiUrl>
#   CAcert: CA certificate to add to truststore /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_TRUSTSTORE
#   name: hostname to assign to this peer
#   name: name (FQDN) from the cert
#   contact: admin email address
#   apiUrl: URL where the peer's federation gateway can be reached
#

function setup_peer() {
  trap 'fail' ERR
  log "Get /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_TRUSTSTORE from $host"
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    $user@$host:/var/$ACUMOS_NAMESPACE/certs/$ACUMOS_TRUSTSTORE .

  log "Check for existing CA cert with alias ${peer}CA"
  if [[ $(keytool -list -v -keystore $ACUMOS_TRUSTSTORE -storepass $ACUMOS_TRUSTSTORE_PASSWORD | grep -ci ${peer}CA) -gt 0 ]]; then
    log "Found existing CA cert with alias ${peer}CA, removing it"
    keytool -delete -alias ${peer}CA \
      -keystore $ACUMOS_TRUSTSTORE \
      -storepass $ACUMOS_CERT_KEY_PASSWORD
  fi

  log "Import peer CA cert into truststore"
  keytool -import -file $CAcert -alias ${peer}CA \
    -keystore $ACUMOS_TRUSTSTORE -storepass $ACUMOS_TRUSTSTORE_PASSWORD -noprompt

  log "Put updated /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_TRUSTSTORE back at $host"
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $ACUMOS_TRUSTSTORE \
    $user@$host:/var/$ACUMOS_NAMESPACE/certs/$ACUMOS_TRUSTSTORE

  if [[ $(curl -s -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -X GET http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/peer | grep -ci "name\":\"${peer}") -eq 0 ]]; then
    log "Create peer relationship for $peer via CDS API"
    apiURL="https://$peer:$ACUMOS_FEDERATION_PORT"
    curl -s -o /tmp/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD \
      -X POST http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/peer \
      -H "accept: */*" -H "Content-Type: application/json" \
      -d "{ \"name\":\"$peer\", \"self\": false, \"local\": false, \"contact1\": \"$contact\", \"name\": \"$peer\", \"apiUrl\": \"$apiUrl\",   \"statusCode\": \"AC\", \"validationStatusCode\": \"PS\" }"
    created=$(jq -r '.created' /tmp/json)
    if [[ "$created" == "null" ]]; then
      cat /tmp/json
      fail "Peer creation failed"
    fi
  else
    log "Peer relationship for $peer already exists"
  fi

  if [[ $(nslookup $peer | grep -c NXDOMAIN) -eq 1 ]]; then
    ip=$(grep $peer /etc/hosts | cut -d ' ' -f 1)
  else
    ip=$(nslookup $peer | awk '/^Address: / { print $2 }' | head -1)
  fi

  log "Add hostalias for $peer at $ip and restart federation to apply new truststore entry"
  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    if [[ $(grep -c "\- \"$peer\"" kubernetes/deployment/federation-deployment.yaml) -eq 0 ]]; then
      log "Save updated federation-deployment.yaml template for use in redeployment"
      # NOTE: hostAliases must be the last section of federation-deployment.yaml
      # and indented as below
      cat <<EOF >>kubernetes/deployment/federation-deployment.yaml
      - ip: "$ip"
        hostnames:
        - "$peer"
EOF
      log "Patch the running federation service, to restart it with the changes"
      cat <<EOF >/tmp/patch.yaml
spec:
  template:
    spec:
      hostAliases:
      - ip: "$ip"
        hostnames:
        - "$peer"
EOF
    kubectl patch deployment -n $ACUMOS_NAMESPACE federation \
      --patch "$(cat /tmp/patch.yaml)"
    else
      # Just add a unique label so that kubernetes restarts federation
      log "Patch the running federation service, to restart it with the changes"
      kubectl patch deployment -n $ACUMOS_NAMESPACE federation  -p \
        "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
    fi
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
    ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $user@$host \
      <<EOF
cd AIO
if [[ $(grep -c "$peer:" docker/acumos/federation.yml) -eq 0 ]]; then
  sed -i -- "/extra_hosts:/a\ \ \ \ \ \ \ \ \ \ \ - \"$peer:$ip\"" \
    docker/acumos/federation.yml
  fi
  source docker-compose.sh up -d --build federation-service
fi
EOF
  fi

  log "Verify federation API is accessible"
  while ! curl -vk --cert /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_CERT \
  --key /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_CERT_KEY \
  https://$ACUMOS_FEDERATION_HOST:$ACUMOS_FEDERATION_PORT/solutions ; do
    log "federation API is not yet accessible. Waiting 10 seconds"
    sleep 10
  done
}

set -x
trap 'fail' ERR

host=$1
user=$2
peer=$3
CAcert=$4
contact=$5

setup_peer
