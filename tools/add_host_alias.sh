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
# - Run this script from the system-integration/tools folder on the Acumos host
# - Hostname/FQDN must be resolvable on the host where this script is run
#
# Usage:
#   To update a docker-compose deployed component
#   $ bash add_host_alias.sh docker <name> <template>
#     name: hostname/FQDN to add
#     template: Full path to the template file
#
#   To update a k8s-based component:
#   $ bash add_host_alias.sh k8s <name> <namespace> <template|app> [component]
#     name: hostname/FQDN to add
#     namespace: k8s namespace
#     template|app: For type 'template', the full path to the template file.
#       For 'deployment', the Acumos component 'app' from
#       deployment template.metadata.labels.app
#     component: (optional) match template.metadata.labels.component
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

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    if [[ $(grep -c "\"$name:$ip\"" $template) -eq 0 ]]; then
      n="$(grep -m 1 '^\( *\)restart:' $template | sed 's/restart:.*//')"
      if [[ $(grep -c "extra_hosts:" $template) -eq 0 ]]; then
        sed -i -- "/restart:.*/a\\${n}extra_hosts:\n$n\ \ - \"$name:$ip\"/g" $template
      else
        sed -i -- "/extra_hosts:/a\\${n}\ \ - \"$name:$ip\"/g" $template
      fi
      cd $(dirname $template)
      cd ..
      trap - ERR
      docker-compose -f acumos/$(basename -- "$template") up -d --build
      trap 'fail' ERR
    fi
  else
    tmp="/tmp/$(uuidgen)"
    if [[ "$(echo $app | grep '\.yaml')" == "" ]]; then
      log "Patch the running deployment for $app, to restart it with the changes"
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
      if [[ $(grep -c "\- ip: \"$ip\"" $app) -eq 0 ]]; then
        n="$(grep -m 1 '^\( *\)restartPolicy:' $app | sed 's/restartPolicy:.*//')"
        if [[ $(grep -c "hostAliases:" $app) -eq 0 ]]; then
          sed -i -- "/restartPolicy:.*/a\\${n}hostAliases:\n$n- ip: \"$ip\"\n$n\ \ hostnames:\n$n\ \ - \"$name\"" $app
        else
          sed -i -- "/hostAliases:.*/a\\${n}- ip: \"$ip\"\n$n\ \ hostnames:\n$n\ \ - \"$name\"" $app
        fi
        replace_env $app
        kubectl delete -f $app
        kubectl create -f $app
        appname=$(grep -m 1 'app: ' $app | awk '{print $2}')
        wait_running $appname $namespace
      fi
    fi
  fi
}

if [[ $# -lt 3 ]]; then
  cat <<'EOF'
To update a docker-compose deployed component
   $ bash add_host_alias.sh docker <name> <template>
     name: hostname/FQDN to add
     template: Full path to the template file

To update a k8s-based component:
   $ bash add_host_alias.sh k8s <name> <namespace> <template|app> [component]
     name: hostname/FQDN to add
     namespace: k8s namespace
     template|app: For type 'template', the full path to the template file.
       For 'deployment', the Acumos component 'app' from
       deployment template.metadata.labels.app
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
source $AIO_ROOT/acumos_env.sh
type=$1
if [[ "$type" == "docker" ]]; then
  name=$2
  template=$3
else
  name=$2
  app=$3
  namespace=$4
  component=$5
fi
add_host_alias
cd $WORK_DIR
