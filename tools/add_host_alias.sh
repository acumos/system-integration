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
# What this is: Utility to add a host alias to an Acumos component, e.g.
# for hostnames/FQDNs that are not resolvable through DNS.
# Prerequisites:
# - Acumos AIO platform deployed, with access to the saved environment files
# - Hostname/FQDN must be resolvable on the host where this script is run
# - For updating docker-based platforms, run this script from the AIO folder
#   on the Acumos host
#
# Usage:
# $ bash add_host_alias.sh <name> <app> <component>
#   name: hostname/FQDN to add
#   app: Acumos component app, from deployment template.metadata.labels.app
#   namespace: (optional) the namespace to use for k8s deployments
#   component: (optional) match template.metadata.labels.component
#

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

  if [[ "$namespace" != "" ]]; then
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
    if [[ "$component" != "" ]]; then c="-l component=$component"; fi
    dep=$(kubectl get deployment -n $namespace -l app=$app $c -o json | jq -r ".items[0].metadata.name")
    kubectl patch deployment -n $namespace $dep --patch "$(cat $tmp)"
    rm $tmp
  else
    c=$(docker ps --filter name=federation --format '{{.ID}}')
    docker exec $c /bin/sh -c "echo \"$ip $name\" >>/etc/hosts"
  fi
}

if [[ $# -lt 2 ]]; then
  cat <<'EOF'
Usage:
  $ bash add_host_alias.sh <name> <app> <component>
    name: hostname/FQDN to add
    app: Acumos component app, from deployment template.metadata.labels.app
    namespace: (optional) the namespace to use for k8s deployments
    component: (optional) match template.metadata.labels.component
EOF
  echo "All parameters not provided"
  exit 1
fi

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
export AIO_ROOT="$(cd ../AIO; pwd -P)"
source $AIO_ROOT/utils.sh
name=$1
app=$2
namespace=$3
component=$4
add_host_alias
cd $WORK_DIR
