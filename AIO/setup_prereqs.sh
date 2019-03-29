#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2019 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
# What this is: Prerequisite setup script for All-in-One (AIO) deployment of the
# Acumos platform. Intended to support users who do not have sudo permission, to
# have a host admin (sudo user) run this script in advance for them.
# FOR TEST PURPOSE ONLY.
#
# Prerequisites:
# - Ubuntu Xenial (16.04), Bionic (18.04), or Centos 7 hosts
# - All hostnames specified in acumos-env.sh must be DNS-resolvable on all hosts
#   (entries in /etc/hosts or in an actual DNS server)
# - User running this script has:
#   - Installed docker per system-integration/tools/setup-docker.sh
#   - Added themselves to the docker group (sudo usermod -G docker $USER)
#   - Logged out and back in, to activate docker group membership
# - If deploying in preparation for use by a non-sudo user
#   - Created the user account (sudo useradd -m <user>)
# - system-integration repo clone (patched, as needed) in home folder
#
# Usage: if deploying under docker, on the target host
# $ bash setup_prereqs.sh <under> <domain> <user> [k8s_dist]
#   under: docker|k8s; install prereqs for docker or k8s based deployment
#   domain: FQDN of platform
#   user: user that will be completing Acumos platform setup via
#         oneclick_deploy.sh (if installing for yousrself, use $USER)
#   k8s_dist: k8s distribution (generic|openshift), required for k8s deployment
#

function wait_dpkg() {
  # TODO: workaround for "E: Could not get lock /var/lib/dpkg/lock - open (11: Resource temporarily unavailable)"
  echo; echo "waiting for dpkg to be unlocked"
  while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
    sleep 1
  done
}

function setup_prereqs() {
  trap 'fail' ERR

  log "/etc/hosts customizations"
  # Ensure cluster hostname resolves inside the cluster
  if [[ $(host $ACUMOS_DOMAIN | grep -c 'not found') -gt 0 ]]; then
    if [[ $(grep -c -P " $ACUMOS_DOMAIN( |$)" /etc/hosts) -eq 0 ]]; then
      log "Add $ACUMOS_DOMAIN to /etc/hosts"
      echo "$ACUMOS_DOMAIN $ACUMOS_HOST_IP" | sudo tee -a /etc/hosts
    fi
  fi

  log "/etc/hosts:"
  cat /etc/hosts

  log "Basic prerequisites"
  if [[ "$HOST_OS" == "ubuntu" ]]; then
    # This us needed to avoid random errors ala "no release file" when trying to
    # update apt, after prior mariadb install using one of the mariadb mirrors.
    # The mirrors may become unreliable, thus the MARIADB_MIRROR env param
    log "Remove any prior reference to mariadb in /etc/apt/sources.list"
    sudo sed -i -- '/mariadb/d' /etc/apt/sources.list
    wait_dpkg; sudo apt-get update
    # TODO: fix need to skip upgrade as this sometimes updates the kube-system
    # services and they then stay in "pending", blocking k8s-based deployment
    # Also on bionic can cause a hang at 'Preparing to unpack .../00-systemd-sysv_237-3ubuntu10.11_amd64.deb ...'
    #  wait_dpkg; sudo apt-get upgrade -y
    wait_dpkg; sudo apt-get install -y wget git jq
  else
    # For centos, only deployment under k8s is supported
    # docker is assumed to be pre-installed as part of the k8s install process
    sudo yum -y update
    sudo rpm -Fvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    sudo yum install -y wget git jq bind-utils
  fi
}

setup_keystore() {
  trap 'fail' ERR

  if [[ ! $(which keytool) ]]; then
    log "Install keytool"
    if [[ "$HOST_OS" == "ubuntu" ]]; then
      sudo apt-get install -y openjdk-8-jre-headless
    else
      sudo yum install -y java-1.8.0-openjdk-headless
    fi
  fi

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    if [[ ! -e /var/$ACUMOS_NAMESPACE/certs ]]; then
      log "Create /var/$ACUMOS_NAMESPACE/certs as cert storage folder"
      sudo mkdir -p /var/$ACUMOS_NAMESPACE/certs
      # Have to set user and group to allow pod access to PVs
      sudo chown $ACUMOS_HOST_USER:$ACUMOS_HOST_USER /var/$ACUMOS_NAMESPACE
    fi
    if [[ "$(ls certs/* | grep -v '\.sh')" != "" ]]; then
      sudo cp $(ls certs/* | grep -v '\.sh') /var/$ACUMOS_NAMESPACE/certs/.
      sudo chown -R $ACUMOS_HOST_USER:$ACUMOS_HOST_USER /var/$ACUMOS_NAMESPACE/certs
    fi
  fi
}

setup_docker() {
  trap 'fail' ERR

  if [[ "$HOST_OS" == "ubuntu" ]]; then
    wait_dpkg; sudo apt-get update

    log "Install latest docker-ce"
    # Per https://docs.docker.com/install/linux/docker-ce/ubuntu/
    wait_dpkg
    if [[ $(sudo apt-get purge -y docker-ce docker docker-engine docker.io) ]]; then
      echo "Purged docker-ce docker docker-engine docker.io"
    fi
    wait_dpkg; sudo apt-get update
    wait_dpkg; sudo apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    wait_dpkg; sudo apt-get update
    apt-cache madison docker-ce
    wait_dpkg; sudo apt-get install -y docker-ce=18.06.3~ce~3-0~ubuntu
  fi

  log "Install latest docker-compose"
  # Required, to use docker compose version 3.2 templates
  # Per https://docs.docker.com/compose/install/#install-compose
  # Current version is listed at https://github.com/docker/compose/releases
  sudo curl -L -o /usr/local/bin/docker-compose \
  "https://github.com/docker/compose/releases/download/1.23.1/docker-compose-$(uname -s)-$(uname -m)"
  sudo chmod +x /usr/local/bin/docker-compose

  log "Enable non-secure docker repositories"
  cat <<EOF | sudo tee /etc/docker/daemon.json
{
"insecure-registries": [
"$ACUMOS_DOCKER_REGISTRY_HOST:$ACUMOS_DOCKER_MODEL_PORT"
],
"disable-legacy-registry": true
}
EOF

  log "Enable docker API on the AIO install host"
  if [[ $(grep -c "\-H tcp://0.0.0.0:$ACUMOS_DOCKER_API_PORT" /lib/systemd/system/docker.service) -eq 0 ]]; then
    sudo sed -i -- "s~ExecStart=/usr/bin/dockerd -H fd://~ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:$ACUMOS_DOCKER_API_PORT~" /lib/systemd/system/docker.service
    # Add another variant of this config setting
    # TODO: find a general solution
    sudo sed -i -- "s~ExecStart=/usr/bin/dockerd -H unix://~ExecStart=/usr/bin/dockerd -H unix:// -H tcp://0.0.0.0:$ACUMOS_DOCKER_API_PORT~" /lib/systemd/system/docker.service
  fi

  log "Block host-external access to docker API except from $ACUMOS_HOST_IP"
  if [[ $(sudo iptables -S | grep -c "172.0.0.0/8 .* $ACUMOS_DOCKER_API_PORT") -eq 0 ]]; then
    sudo iptables -A INPUT -p tcp --dport $ACUMOS_DOCKER_API_PORT ! -s 172.0.0.0/8 -j DROP
  fi
  if [[ $(sudo iptables -S | grep -c "127.0.0.1/32 .* $ACUMOS_DOCKER_API_PORT") -eq 0 ]]; then
    sudo iptables -I INPUT -s localhost -p tcp -m tcp --dport $ACUMOS_DOCKER_API_PORT -j ACCEPT
  fi
  if [[ $(sudo iptables -S | grep -c "$ACUMOS_HOST_IP/32 .* $ACUMOS_DOCKER_API_PORT") -eq 0 ]]; then
    sudo iptables -I INPUT -s $ACUMOS_HOST_IP -p tcp -m tcp --dport $ACUMOS_DOCKER_API_PORT -j ACCEPT
  fi

  log "Restart the docker service to apply the changes"
  # NOTE: the need to do this is why docker-dind is required for OpenShift;
  # restarting the docker service kills all docker-based services in centos
  # and they are not restarted - thus this kills the OpenShift stack
  sudo systemctl daemon-reload
  sudo service docker restart
  url=http://$ACUMOS_HOST_IP:$ACUMOS_DOCKER_API_PORT
  log "Wait for docker API to be ready at $url"
  until [[ "$(curl $url)" == '{"message":"page not found"}' ]]; do
    log "docker API not ready ... waiting 10 seconds"
    sleep 10
  done
}

function prepare_mariadb() {
  trap 'fail' ERR

  # Do not reset mariadb service/data unless deploying via oneclick_deploy
  if [[ "$ACUMOS_DEPLOY_MARIADB" == "true" ]]; then
    if [[ ! -e mariadb-env.sh ]]; then
      source ../charts/mariadb/setup-mariadb-env.sh
      cp mariadb-env.sh ../charts/mariadb/.
    fi

    log "Stop any existing components for mariadb-service"
    if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
      if [[ "$K8S_DIST" == "generic" ]]; then
        if [[ $(helm delete --purge mariadb) ]]; then
          log "Helm release mariadb deleted"
        fi
      fi
      delete_namespace $ACUMOS_MARIADB_NAMESPACE
      delete_pvc $ACUMOS_MARIADB_NAMESPACE $MARIADB_DATA_PVC_NAME
    else
      cd mariadb
      source docker-compose.sh down
      cd ..
    fi
    log "Remove any existing PV data for mariadb-service"
    delete_pv mariadb-data $ACUMOS_MARIADB_NAMESPACE
    log "Setup the mariadb-data PV"
    reset_pv mariadb-data $ACUMOS_MARIADB_NAMESPACE \
      $MARIADB_DATA_PV_SIZE "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
  fi

  if [[ ! -e mariadb-env.sh ]]; then
    fail "No mariadb-env.sh found. Please provide one or set ACUMOS_DEPLOY_MARIADB=true"
  fi
}

function prepare_docker_engine() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    cd docker-engine
    source setup-docker-engine.sh clean
    cd ..
  fi
  reset_pv docker-volume $ACUMOS_NAMESPACE $DOCKER_VOLUME_PV_SIZE \
    "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
}

function prepare_acumos() {
  trap 'fail' ERR
  if [[ $($k8s_cmd delete $k8s_nstype $ACUMOS_NAMESPACE) ]]; then
    # Deleting namespace deletes all services, deployments, PVCs, ...
    # including core components, kong, nexus, and beats
    while $k8s_cmd get $k8s_nstype $ACUMOS_NAMESPACE; do
      log "Waiting 10 seconds for namespace $ACUMOS_NAMESPACE to be deleted"
      sleep 10
    done
  fi

  reset_pv logs $ACUMOS_NAMESPACE $ACUMOS_LOGS_PV_SIZE \
    "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    reset_pv certs $ACUMOS_NAMESPACE $ACUMOS_CERTS_PV_SIZE \
      "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
  fi
}

function prepare_kong() {
  trap 'fail' ERR
  reset_pv kong-db $ACUMOS_NAMESPACE $KONG_DB_PV_SIZE \
    "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
}

function prepare_nexus() {
  trap 'fail' ERR
  if [[ "$ACUMOS_DEPLOY_NEXUS" == "true" ]]; then
  reset_pv nexus-data $ACUMOS_NAMESPACE $NEXUS_DATA_PV_SIZE \
    "200:$ACUMOS_HOST_USER"
  fi
}

function prepare_elk() {
  trap 'fail' ERR

  if [[ "$ACUMOS_DEPLOY_ELK" == "true" ]]; then
    source ../charts/elk-stack/setup-elk-env.sh
    cp elk-env.sh ../charts/elk-stack/.
    if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
      delete_namespace $ACUMOS_ELK_NAMESPACE
    fi
    reset_pv elasticsearch-data $ACUMOS_ELK_NAMESPACE \
      $ACUMOS_ELASTICSEARCH_DATA_PV_SIZE "1000:1000"
  fi
}

function prepare_env() {
  trap 'fail' ERR
  source utils.sh
  sed -i -- "s/DEPLOY_RESULT=.*/DEPLOY_RESULT=/" acumos-env.sh
  sed -i -- "s/FAIL_REASON=.*/FAIL_REASON=/" acumos-env.sh
  update_env AIO_ROOT $WORK_DIR
  update_env DEPLOYED_UNDER $1 force
  update_env ACUMOS_DOMAIN $2 force
  update_env ACUMOS_HOST_USER $3 force
  update_env K8S_DIST "$4" force
  set_k8s_env

  update_env ACUMOS_HOST $(hostname) force
  ACUMOS_HOST_IP=$(/sbin/ip route get 8.8.8.8 | head -1 | sed 's/^.*src //' | awk '{print $1}')
  update_env ACUMOS_HOST_IP $ACUMOS_HOST_IP force

  # Local host info variables used here and in other sourced scripts
  get_host_info
  update_env ACUMOS_HOST_OS $HOST_OS
  update_env ACUMOS_HOST_OS_VER $HOST_OS_VER
  source acumos-env.sh
}

set -x
cd ~/system-integration/AIO
WORK_DIR=$(pwd)
prepare_env $1 $2 $3 $4
trap 'fail' ERR
setup_prereqs

if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
  setup_docker
fi

prepare_mariadb
prepare_elk
bash ../tools/setup_mariadb_client.sh $AIO_ROOT
setup_keystore
if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
  delete_namespace $ACUMOS_NAMESPACE
fi
prepare_docker_engine
prepare_acumos
prepare_kong
prepare_nexus

cd ~
mkdir -p acumos/env acumos/certs acumos/logs
cp system-integration/AIO/*-env.sh acumos/env/.

if [[ "$ACUMOS_HOST_USER" != "$USER" ]]; then
  log "Add $ACUMOS_HOST_USER to the docker group"
  sudo usermod -G docker $ACUMOS_HOST_USER
  # Setup the acumos user env
  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    sudo cp -r .kube /home/$ACUMOS_HOST_USER/.
    sudo chown -R $ACUMOS_HOST_USER:$ACUMOS_HOST_USER /home/$ACUMOS_HOST_USER/.kube
  fi
  sudo cp -r acumos /home/$ACUMOS_HOST_USER/.
  sudo chown -R $ACUMOS_HOST_USER:$ACUMOS_HOST_USER /home/$ACUMOS_HOST_USER/acumos
fi

set +x
log "Prerequisites setup is complete."
if [[ -e /tmp/json ]]; then sudo rm /tmp/json; fi
if [[ -e /tmp/acumos ]]; then sudo rm -rf /tmp/acumos; fi
