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
# - cd docker-engine; bash setup-docker-engine.sh
#

setup_prereqs() {
  if [[ "$dist" == "ubuntu" ]]; then
    if [[ "$DEPLOYED_UNDER" = "docker" ]]; then
      distver=$(grep -m 1 'VERSION_ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
      case "$distver" in
        "16.04")
          log "Install docker-ce if needed"
          dce=$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' 'docker-ce')
          if [[ $dce != "installed" ]]; then
            echo; echo "prereqs.sh: ($(date)) Install latest docker-ce"
            # Per https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/
            sudo apt-get purge -y docker docker-engine docker.io
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
            sudo apt-get install -y docker-ce
          fi
          ;;
        "18.04")
          log "Install docker.io if needed"
          dio=$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' 'docker.io')
          if [[ $dio != "installed" ]]; then
            sudo apt-get purge -y docker docker-engine docker-ce docker-ce-cli
            sudo apt-get update
            sudo apt-get install -y docker.io=17.12.1-0ubuntu1
            sudo systemctl enable docker.service
          fi
          ;;
        *)
          fail "Unsupported Ubuntu version ($distver)"
      esac
    fi
  fi
}

setup() {
  if [[ "$DEPLOYED_UNDER" = "docker" ]]; then
     log "Enable docker API on the AIO install host"
     if [[ $(grep -c "\-H tcp://0.0.0.0:$ACUMOS_DOCKER_API_PORT" /lib/systemd/system/docker.service) -eq 0 ]]; then
       sudo sed -i -- "s~ExecStart=/usr/bin/dockerd -H fd://~ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:$ACUMOS_DOCKER_API_PORT~" /lib/systemd/system/docker.service
       # Add another variant of this config setting
       # TODO: find a general solution
       sudo sed -i -- "s~ExecStart=/usr/bin/dockerd -H unix://~ExecStart=/usr/bin/dockerd -H unix:// -H tcp://0.0.0.0:$ACUMOS_DOCKER_API_PORT~" /lib/systemd/system/docker.service
     fi

     log "Block host-external access to docker API"
     if [[ $(sudo iptables -S | grep -c '172.0.0.0/8 .* 2375') -eq 0 ]]; then
       sudo iptables -A INPUT -p tcp --dport 2375 ! -s 172.0.0.0/8 -j DROP
     fi
     if [[ $(sudo iptables -S | grep -c '127.0.0.1/32 .* 2375') -eq 0 ]]; then
       sudo iptables -I INPUT -s localhost -p tcp -m tcp --dport 2375 -j ACCEPT
     fi
     if [[ $(sudo iptables -S | grep -c "$ACUMOS_HOST/32 .* 2375") -eq 0 ]]; then
       sudo iptables -I INPUT -s $ACUMOS_HOST -p tcp -m tcp --dport 2375 -j ACCEPT
     fi

     log "Enable non-secure docker repositories"
     cat << EOF | sudo tee /etc/docker/daemon.json
{
   "insecure-registries": [
     "$ACUMOS_NEXUS_HOST:$ACUMOS_DOCKER_MODEL_PORT"
   ],
   "disable-legacy-registry": true
}
EOF
     log "Restart the docker service to apply the changes"
     # NOTE: the need to do this is why docker-dind is required for OpenShift;
     # restarting the docker service kills all docker-based services in centos
     # and they are not restarted - thus this kills the OpenShift stack
     sudo systemctl daemon-reload
     sudo service docker restart
     log "Verify docker API is accessible"
     url=http://$ACUMOS_DOCKER_API_HOST:$ACUMOS_DOCKER_API_PORT
  else
    log "Stop any existing k8s based components for docker-service"
    stop_service deploy/docker-service.yaml
    stop_deployment deploy/docker-deployment.yaml
    log "Delete the $ACUMOS_NAMESPACE-docker-volume PVC"
    bash $AIO_ROOT/etup-pv.sh clean pvc docker-volume

    log "Setup the $ACUMOS_NAMESPACE-docker-volume PV"
    bash $AIO_ROOT/setup-pv.sh setup pv docker-volume \
      $PV_SIZE_DOCKER_VOLUME "$USER:$USER"
    log "Setup the $ACUMOS_NAMESPACE-docker-volume PVC"
    bash $AIO_ROOT/setup-pv.sh setup pvc docker-volume \
      $PV_SIZE_DOCKER_VOLUME

    log "Deploy the k8s based components for docker-service"
    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    replace_env deploy "ACUMOS_DOCKER_API_PORT ACUMOS_DOMAIN ACUMOS_HOST \
      ACUMOS_NAMESPACE ACUMOS_NEXUS_HOST HTTPS_PROXY HTTP_PROXY \
      ACUMOS_DOCKER_MODEL_PORT"

    start_service deploy/docker-service.yaml
    start_deployment deploy/docker-deployment.yaml
    wait_running docker-service
    ip=$(kubectl get svc -n acumos docker-service | awk '/docker-service/{print $3}')
    url=http://$ip:$ACUMOS_DOCKER_API_PORT
  fi

  log "Wait for docker API to be ready at $url"
  while ! curl $url; do
    log "docker API not ready ... waiting 10 seconds"
    sleep 10
  done
}

source $AIO_ROOT/acumos-env.sh
source $AIO_ROOT/utils.sh
setup_prereqs
setup
