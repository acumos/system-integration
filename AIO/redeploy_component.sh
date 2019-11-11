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
# - Key-based SSH access to the Acumos host, for updating docker images
#
# Usage: see below

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
    app="$app-service"
    if [[ "$(grep -l " $app:" docker/acumos/*)" != "" ]]; then
      yaml=$(basename $(grep -l " $app:" docker/acumos/*))
      cd docker
      # add '&& true' since 'down' will trap an error due to detecting that
      # 'network acumos_default id ... has active endpoints' (irrelevant)
      log "Bring the $app service down"
      docker-compose -f acumos/$yaml down && true
      if [[ "$app" == "sv-scanning-service" ]]; then
        log "Prepare the sv-scanning config volume"
        rm -rf /mnt/$ACUMOS_NAMESPACE/sv/*
        cp -r $AIO_ROOT/kubernetes/configmap/sv-scanning/* /mnt/$ACUMOS_NAMESPACE/sv/.
      fi
      if [[ "$image" != "" ]]; then
        image=$(docker image list | awk "/$image/{print \$3}")
        if [[ "$image" != "" ]]; then
          docker image rm $image
        fi
      fi
      log "Bring the $app service back up"
      docker-compose -f acumos/$yaml up -d --build
    else
      fail "$app not found in $AIO_ROOT/docker/acumos"
    fi
  else
    if [[ "$(grep -l "app: $app" kubernetes/service/*)" != "" ]]; then
      stop_acumos_core_app $app
      while [[ $(kubectl get pods -n $ACUMOS_NAMESPACE -l app=$app) ]]; do
        log "Waiting 10 seconds for app pod to be terminated"
        sleep 10
      done
      start_acumos_core_app $app
    else
      fail "$app not found; verify the 'app:' label in the template"
    fi
  fi
}

if [[ $# -lt 1 ]]; then
  cat <<'EOF'
Usage:
  For docker-based deployments run this script on the AIO install host.
  For k8s-based deployments run this script on the AIO install host or on
  a workstation configured for remote use of kubectl/oc, e.g. as setup by
  system-integration/tools/setup_kubectl.sh or
  system-integration/tools/setup_openshift_client.sh

  $ bash redeploy_component.sh <component> [image=<image>] [tail]
    component: name of the component. For core components (those under
    AIO/docker/acumos or AIO/kubernetes/deployment), this is the name of the
    docker "service" or the k8s "app" value from the deployment template.
    Any modificationa to acumos_env.sh or the deployment template will be
    applied, using the templates in the applicable source folder.
    Other components can be redeployed by the names: metricbeat, filebeat,
    docker-proxy, elk-stack, kong, docker-dind (under k8s only).
    Note: mariadb and nexus are not supported at this time as redeploying them
    alone may reset/corrupt platform data (support is planned).
    image=<image>: (optional) docker image to cleanup; this should be a string that
      can uniquely identify the images to be cleaned up when the component
      is down. Useful mostly for forcing re-pull of snapshot images.
      Example: 'security-verification' will delete all images with that string
      in the image reference.
    tail: (optional) after deployment, tail the logs.
EOF
  echo "All parameters not provided"
  exit 1
fi

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
source utils.sh
source acumos_env.sh
app=$1
ps="$2 $3"
for p in $ps; do
  if [[ "$p" == *"image="* ]]; then
    image=$(echo $p | cut -d '=' -f 2)
  elif [[ "$p" == "tail" ]]; then
    tail=true
  fi
done

case "$app" in
  metricbeat)
    bash $AIO_ROOT/beats/setup_beats.sh metricbeat
    [ "$tail" == "true" ] && tail_logs $ACUMOS_NAMESPACE metricbeat
    ;;
  filebeat)
    bash $AIO_ROOT/beats/setup_beats.sh filebeat
    [ "$tail" == "true" ] && tail_logs $ACUMOS_NAMESPACE metricbeat
    ;;
  docker-dind)
    if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
      bash $AIO_ROOT/docker-engine/setup_docker_engine.sh
    else
      fail "Redeploying the host-based docker-engine is not supported"
    fi
    [ "$tail" == "true" ] && tail_logs acumos docker-dind docker-daemon
    ;;
  docker-proxy)
    bash $AIO_ROOT/docker-proxy/setup_docker_proxy.sh
    [ "$tail" == "true" ] && tail_logs $ACUMOS_NAMESPACE docker-proxy
    ;;
  elk-stack)
    bash $AIO_ROOT/elk-stack/setup_elk.sh
    [ "$tail" == "true" ] && tail_logs $ACUMOS_ELK_NAMESPACE logstash
    ;;
  kong)
    bash $AIO_ROOT/kong/setup_kong.sh
    [ "$tail" == "true" ] && tail_logs $ACUMOS_NAMESPACE kong kong
    ;;
  *)
    redeploy_core_component
    [ "$tail" == "true" ] && tail_logs $ACUMOS_NAMESPACE $app
esac
cd $WORK_DIR
