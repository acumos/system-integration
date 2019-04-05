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
# What this is: script for re-deploying an Acumos core component
#
# Prerequisites:
# - Acumos AIO platform deployed
# - Access to system-integration clone, as updated during the install process
#
# Usage: see below

set -x
if [[ $# -lt 1 ]]; then
  echo <<'EOF'
Usage:
  For docker-based deployments run this script on the AIO install host.
  For k8s-based deployments run this script on the AIO install host or on
  a workstation configured for remote use of kubectl/oc, e.g. as setup by
  system-integration/tools/setup_kubectl.sh or
  system-integration/tools/setup_openshift_client.sh

  $ bash redeploy_component.sh <component>
    component: name of the component. For docker-based deployment, this is the
    name of the service (from the docker-compose file in AIO/docker/acumos).
    For k8s-based deployment, this is the "app" value from the deployment
    template in AIO/kubernetes/deployment. Any modificationa to acumos_env.sh
    or the deployment template will be applied, using the templates in
    AIO/docker/acumos or AIO/kubernetes/deployment, as applicable.

    If redeployment is successful, the script will tail the component's logs.
    Hit ctrl-c to stop tailing the logs.
EOF
  echo "All parameters not provided"
  exit 1
fi

function redeploy_component() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    if [[ "$(grep -l " $app:" docker/acumos/*)" != "" ]]; then
      yaml=$(basename $(grep -l " $app:" docker/acumos/*))
      cd docker
      # add '&& true' since 'down' will trap an error due to detecting that
      # 'network acumos_default id ... has active endpoints' (irrelevant)
      docker-compose -f acumos/$yaml down && true
      docker-compose -f acumos/$yaml up -d --build
      docker logs -f $(docker ps -a | awk "/$app/{print \$1}")
    else
      fail "$app not found in docker/acumos"
    fi
  else
    if [[ "$(grep -l "app: $app" kubernetes/deployment/*)" != "" ]]; then
      yaml=$(basename $(grep -l "app: $app" kubernetes/deployment/*))
      if [[ ! -e deploy ]]; then mkdir deploy; fi
      cp kubernetes/deployment/$yaml deploy/.
      replace_env deploy
      stop_deployment deploy/$yaml
      start_deployment deploy/$yaml
      wait_running $app acumos
      pod=$(kubectl get pods -n acumos | awk "/$app/{print \$1}")
      kubectl logs -f -n acumos $pod
    else
      fail "$app not found in $AIO_ROOT/kubernetes/deployment"
    fi
  fi
}

app=$1
cd $(dirname "$0")
source acumos_env.sh
export AIO_ROOT=$(pwd)
source utils.sh

function fail() {
  log "$1"
  exit 1
}

redeploy_component
