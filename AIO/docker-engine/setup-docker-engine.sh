#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
# What this is: Deployment script for the docker-engine and API server as a
# dependency of the Acumos platform.
#
# Prerequisites:
# - Ubuntu Xenial or Centos 7 server
# - acumos-env.sh customized for this platform, as by oneclick_deploy.sh
#
# Usage: intended to be called from oneclick_deploy.sh
#

setup_prereqs() {
  get_host_info
  if [[ "$HOST_OS" == "ubuntu" ]]; then
    case "$HOST_OS_VER" in
      "16.04")
        dce=$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' 'docker-ce')
        if [[ $dce != "installed" ]]; then
          log "prereqs.sh: ($(date)) Install latest docker-ce"
          # Per https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/
          sudo apt-get purge -y docker-ce docker docker-engine docker.io
          sudo apt-get update
          sudo apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            software-properties-common
          curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
          sudo add-apt-repository "deb [arch=amd64] \
            https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
          sudo apt-get update
          sudo apt-get install -y docker-ce=17.03.3~ce-0~ubuntu-xenial
        fi
        ;;
      "18.04")
        dio=$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' 'docker.io')
        if [[ $dio != "installed" ]]; then
          sudo apt-get purge -y docker docker-engine docker-ce docker-ce-cli
          sudo apt-get update
          sudo apt-get install -y docker.io=17.12.1-0ubuntu1
          sudo systemctl enable docker.service
        fi
        ;;
    esac
  fi
}

function clean() {
  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    log "Stop any existing k8s based components for docker-service"
    stop_service deploy/docker-service.yaml
    stop_deployment deploy/docker-deployment.yaml
    log "Removing PVC for docker-engine"
    source $AIO_ROOT/setup-pv.sh clean pvc docker-volume $ACUMOS_NAMESPACE
  fi

  log "Removing PV data for docker-engine"
  source $AIO_ROOT/setup-pv.sh clean pv docker-volume $ACUMOS_NAMESPACE
}

function enable_docker_api() {
  if [[ $(grep -c "\-H tcp://0.0.0.0:$ACUMOS_DOCKER_API_PORT" /lib/systemd/system/docker.service) -eq 0 ]]; then
    sudo sed -i -- "s~ExecStart=/usr/bin/dockerd -H fd://~ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:$ACUMOS_DOCKER_API_PORT~" /lib/systemd/system/docker.service
    # Add another variant of this config setting
    # TODO: find a general solution
    sudo sed -i -- "s~ExecStart=/usr/bin/dockerd -H unix://~ExecStart=/usr/bin/dockerd -H unix:// -H tcp://0.0.0.0:$ACUMOS_DOCKER_API_PORT~" /lib/systemd/system/docker.service
  fi

  log "Block host-external access to docker API except from $ACUMOS_HOST"
  if [[ $(sudo iptables -S | grep -c "172.0.0.0/8 .* $ACUMOS_DOCKER_API_PORT") -eq 0 ]]; then
    sudo iptables -A INPUT -p tcp --dport $ACUMOS_DOCKER_API_PORT ! -s 172.0.0.0/8 -j DROP
  fi
  if [[ $(sudo iptables -S | grep -c "127.0.0.1/32 .* $ACUMOS_DOCKER_API_PORT") -eq 0 ]]; then
    sudo iptables -I INPUT -s localhost -p tcp -m tcp --dport $ACUMOS_DOCKER_API_PORT -j ACCEPT
  fi
  if [[ $(sudo iptables -S | grep -c "$ACUMOS_HOST/32 .* $ACUMOS_DOCKER_API_PORT") -eq 0 ]]; then
    sudo iptables -I INPUT -s $ACUMOS_HOST -p tcp -m tcp --dport $ACUMOS_DOCKER_API_PORT -j ACCEPT
  fi

  log "Restart the docker service to apply the changes"
  # NOTE: the need to do this is why docker-dind is required for OpenShift;
  # restarting the docker service kills all docker-based services in centos
  # and they are not restarted - thus this kills the OpenShift stack
  sudo systemctl daemon-reload
  sudo service docker restart
  url=http://$1:$ACUMOS_DOCKER_API_PORT
  log "Wait for docker API to be ready at $url"
  until [[ "$(curl $url)" == '{"message":"page not found"}' ]]; do
    log "docker API not ready ... waiting 10 seconds"
    sleep 10
  done
}

function setup() {
  log "Setup the docker-volume PV"
  source $AIO_ROOT/setup-pv.sh setup pv docker-volume \
    $ACUMOS_NAMESPACE $DOCKER_VOLUME_PV_SIZE "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
  if [[ "$DEPLOYED_UNDER" = "docker" ]]; then
    # Don't disturb current docker engine if redeploying, otherwise all
    # services will be restarted, breaking MariaDB and Nexus etc
    if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
        log "Enable non-secure docker repositories"
        cat <<EOG | sudo tee /etc/docker/daemon.json
{
  "insecure-registries": [
    "$ACUMOS_DOCKER_REGISTRY_HOST:$ACUMOS_DOCKER_MODEL_PORT"
  ],
 "disable-legacy-registry": true
}
EOG

      log "Enable docker API on the AIO install host"
      enable_docker_api $ACUMOS_HOST
    fi
  else
    log "Setup the $ACUMOS_NAMESPACE-docker-volume PVC"
    source $AIO_ROOT/setup-pv.sh setup pvc docker-volume \
      $ACUMOS_NAMESPACE $DOCKER_VOLUME_PV_SIZE

    log "Deploy the k8s based components for docker-service"
    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    replace_env deploy

    start_service deploy/docker-service.yaml
    start_deployment deploy/docker-deployment.yaml
    wait_running docker-service

    # Note: since the docker API is exposed at a ClusterIP and not a NodePort
    # for security reasons, it's not possible for a tenant-based k8s deployment
    # to remotely check the docker-engine API for readiness. This may be
    # addressed in later releases as needed, by a ClusterIP service test
    # job under k8s. But for now the earlier wait for docker-engine API
    # readiness is removed.
  fi
}

setup_prereqs
setup
