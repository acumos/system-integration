#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2019 AT&T Intellectual Property. All rights reserved.
# ===================================================================================
# This Acumos software file is distributed by AT&T
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
# What this is: Utility to add a host alias to an Acumos core component, e.g.
# for hostnames/FQDNs that are not resolvable through DNS.
# Prerequisites:
# - Acumos AIO platform deployed, with access to the saved environment files
# - Hostname/FQDN must be resolvable on the host where this script is run
# - For updating docker-based platforms, run this script from the AIO folder
#   on the Acumos host
#
# Usage:
# $ bash add-host-alias.sh <env> <name> <app>
#   env: path to local platform environment file acumos_env.sh
#   name: hostname/FQDN to add
#   app: Acumos component app, from deployment template.metadata.labels.app
#

function fail() {
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

function add_host_alias() {
  trap 'fail' ERR
  log "Determining host IP address for $name"
  if [[ $(host $name | grep -c 'not found') -eq 0 ]]; then
    ip=$(host $name | head -1 | cut -d ' ' -f 4)
  elif [[ $(grep -c -E " $name( |$)" /etc/hosts) -gt 0 ]]; then
    ip=$(grep -E " $name( |$)" /etc/hosts | cut -d ' ' -f 1)
  else
    log "Please ensure $name is resolvable thru DNS or hosts file"
    fail "IP address of $name cannot be determined."
  fi

  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    log "Patch the running deployment for $app, to restart it with the changes"
    tmp="/tmp/$(uuidgen)"
    cat <<EOF >$tmp
spec:
  template:
    spec:
      hostAliases:
      - ip: "$ip"
        hostnames:
        - "$name"
EOF
    kubectl patch deployment -n $ACUMOS_NAMESPACE $app --patch "$(cat $tmp)"
    rm $tmp
  else
    c=$(docker ps -a | awk "/$app/{print \$1}")
    docker exec $c /bin/sh -c "echo \"$ip $name\" >>/etc/hosts"
  fi
}

set -x
trap 'fail' ERR

env=$1
name=$2
app=$3

WORK_DIR=$(pwd)
set +x
source $env
set -x
add_host_alias
cd $WORK_DIR
