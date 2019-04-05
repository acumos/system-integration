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
# What this is: script for re-deploying an Acumos component
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
    component: name of the component. For core components (those under
    AIO/docker/acumos or AIO/kubernetes/deployment), this is the name of the
    docker "service" or the k8s "app" value from the deployment template.
    Any modificationa to acumos_env.sh or the deployment template will be
    applied, using the templates in the applicable source folder.
    Other components can be redeployed by the names: metricbeat, filebeat,
    docker-proxy, elk-stack, kong, docker-dind (under k8s only).
    Note: mariadb and nexus are not supported at this time as redeploying them
    alone may reset/corrupt platform data (support is planned).

    If redeployment is successful, the script will tail the component's logs.
    Hit ctrl-c to stop tailing the logs.
EOF
  echo "All parameters not provided"
  exit 1
fi

function tail_logs() {
  # Optionally specify a specific container, for a multi-container pod
  namespace=$1
  app=$2
  container=$3
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    docker logs -f $(docker ps -a | awk "/$app/{print \$1}")
  else
    pod=$(kubectl get pods -n $namespace -l app=$app | awk "/$app-/{print \$1}")
    kubectl logs -f -n $namespace $pod $container
  fi
}

function redeploy_core_component() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    if [[ "$(grep -l " $app:" docker/acumos/*)" != "" ]]; then
      yaml=$(basename $(grep -l " $app:" docker/acumos/*))
      cd docker
      # add '&& true' since 'down' will trap an error due to detecting that
      # 'network acumos_default id ... has active endpoints' (irrelevant)
      docker-compose -f acumos/$yaml down && true
      docker-compose -f acumos/$yaml up -d --build
    else
      fail "$app not found in $AIO_ROOT/docker/acumos"
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
    else
      fail "$app not found in $AIO_ROOT/kubernetes/deployment"
    fi
  fi
  tail_logs acumos $app
}

app=$1
WORK_DIR=$(pwd)
cd $(dirname "$0")
source acumos_env.sh
export AIO_ROOT=$(pwd)
source utils.sh

function fail() {
  log "$1"
  cd $WORK_DIR
  exit 1
}

case "$app" in
  metricbeat)
    bash $AIO_ROOT/beats/setup_beats.sh $AIO_ROOT metricbeat
    tail_logs acumos metricbeat
    ;;
  filebeat)
    bash $AIO_ROOT/beats/setup_beats.sh $AIO_ROOT filebeat
    tail_logs acumos metricbeat
    ;;
  docker-dind)
    if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
      bash $AIO_ROOT/docker-engine/setup_docker_engine.sh $AIO_ROOT
    else
      fail "Redeploying the host-based docker-engine is not supported"
    fi
    tail_logs acumos docker-dind docker-daemon
    ;;
  docker-proxy)
    bash $AIO_ROOT/docker-proxy/setup_docker_proxy.sh $AIO_ROOT
    tail_logs acumos docker-proxy
    ;;
  elk-stack)
    bash $AIO_ROOT/elk-stack/setup_elk.sh $AIO_ROOT
    tail_logs acumos-elk logstash
    ;;
  kong)
    bash $AIO_ROOT/kong/setup_kong.sh $AIO_ROOT
    tail_logs acumos kong kong
    ;;
  *)
    redeploy_core_component
esac
cd $WORK_DIR
