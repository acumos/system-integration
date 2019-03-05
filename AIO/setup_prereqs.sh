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
#
# Usage: if deploying under docker, on the target host
# $ bash setup_prereqs.sh <under> <host> <user>
#   under: docker|k8s; install prereqs for docker or k8s based deployment
#   host: domain name of target host
#   user: user to add to the docker group
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
      echo; echo "prereqs.sh: ($(date)) Add $ACUMOS_DOMAIN to /etc/hosts"
      echo "$ACUMOS_DOMAIN $ACUMOS_HOST_IP" | sudo tee -a /etc/hosts
    fi
  fi

  log "/etc/hosts:"
  cat /etc/hosts

  log "Basic prerequisites"
  if [[ "$HOST_OS" == "ubuntu" ]]; then
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

install_mariadb_client() {
  trap 'fail' ERR

  sudo apt-get install software-properties-common -y
  case "$HOST_OS_VER" in
    "16.04")
      MARIADB_REPO="deb [arch=amd64,i386,ppc64el] http://sfo1.mirrors.digitalocean.com/mariadb/repo/$ACUMOS_MARIADB_VERSION/ubuntu xenial main"
      ;;
    "18.04")
      MARIADB_REPO="deb [arch=amd64,arm64,ppc64el] http://mirror.rackspace.com/mariadb/repo/$ACUMOS_MARIADB_VERSION/ubuntu bionic main"
      ;;
    *)
      fail "Unsupported Ubuntu version ($HOST_OS_VER)"
  esac

  log "Import mariadb repo key"
  sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
  sudo add-apt-repository "$MARIADB_REPO"
  sudo apt-get update -y

  log "Installing MariaDB client $ACUMOS_MARIADB_VERSION"
  if [[ "$HOST_OS" == "ubuntu" ]]; then
    sudo apt-get install -y mariadb-client
  else
  # Add MariaDB 10 external yum repo
    cat << EOF | sudo tee -a /etc/yum.repos.d/MariaDB.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.2/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
    sudo yum install -y MariaDB-client
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
    sudo cp $(ls certs/* | grep -v '\.sh') /var/$ACUMOS_NAMESPACE/certs/.
    sudo chown -R $ACUMOS_HOST_USER:$ACUMOS_HOST_USER /var/$ACUMOS_NAMESPACE/certs
  fi
}

setup_docker() {
  trap 'fail' ERR

  if [[ "$HOST_OS" == "ubuntu" ]]; then
    case "$HOST_OS_VER" in
      "16.04")
        sudo apt-get update
        if [[ "$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' 'docker-ce')" != "installed" ]]; then
          log "Install latest docker-ce"
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
        sudo apt-get update
        if [[ "$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' 'docker.io')" != "installed" ]]; then
          log "Install latest docker.io"
          sudo apt-get purge -y docker docker-engine docker-ce docker-ce-cli
          sudo apt-get update
          sudo apt-get install -y docker.io=17.12.1-0ubuntu1
          sudo systemctl enable docker.service
        fi
        ;;
    esac
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

  if [[ -e mariadb-env.sh ]]; then
    source mariadb-env.sh
    export ACUMOS_DEPLOY_MARIADB=false
    sed -i -- "s/ACUMOS_DEPLOY_MARIADB=.*/ACUMOS_DEPLOY_MARIADB=$ACUMOS_DEPLOY_MARIADB/" acumos-env.sh
    echo "source mariadb-env.sh" >>acumos-env.sh
  else
    source ../charts/mariadb/setup-mariadb-env.sh
    cp mariadb-env.sh ../charts/mariadb/.
    if [[ "$ACUMOS_DEPLOY_MARIADB" == "true" ]]; then
      log "Stop any existing components for mariadb-service"
      if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
        cd mariadb
        source docker-compose.sh down
        cd ..
      else
        if [[ $(helm delete --purge mariadb) ]]; then
          log "Helm release mariadb deleted"
        fi
        log "Remove any existing PVC data for mariadb-service"
        if [[ "$($k8s_cmd get pvc -n $ACUMOS_MARIADB_NAMESPACE | awk '/mariadb/{print $1}')" != "" ]]; then
          $k8s_cmd delete pvc -n $ACUMOS_MARIADB_NAMESPACE \
            $($k8s_cmd get pvc -n $ACUMOS_MARIADB_NAMESPACE | awk '/mariadb/{print $1}')
        fi
      fi
      log "Remove any existing PV data for mariadb-service"
      source setup-pv.sh clean pv mariadb-data $ACUMOS_MARIADB_NAMESPACE
      log "Setup the mariadb-data PV"
      source setup-pv.sh setup pv mariadb-data \
        $ACUMOS_MARIADB_NAMESPACE $MARIADB_DATA_PV_SIZE "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
    fi
  fi
  echo "source mariadb-env.sh" >>acumos-env.sh
}

function prepare_docker_engine() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    cd docker-engine
    source setup-docker-engine.sh clean
    cd ..
  fi
  log "Remove any existing PV data for docker-volume"
  source setup-pv.sh clean pv docker-volume $ACUMOS_NAMESPACE
  log "Setup the docker-volume PV"
  source setup-pv.sh setup pv docker-volume \
    $ACUMOS_NAMESPACE $DOCKER_VOLUME_PV_SIZE "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
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

  log "Remove any existing PV data for acumos-logs"
  source setup-pv.sh clean pv logs $ACUMOS_NAMESPACE
  log "Setup the acumos-logs PV"
  source setup-pv.sh setup pv logs $ACUMOS_NAMESPACE $ACUMOS_LOGS_PV_SIZE \
    "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Remove any existing PV data for acumos-certs"
    source setup-pv.sh clean pv certs $ACUMOS_NAMESPACE
    log "Setup the acumos-certs PV"
    source setup-pv.sh setup pv certs $ACUMOS_NAMESPACE $ACUMOS_CERTS_PV_SIZE \
      "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
  fi
}

function prepare_kong() {
  trap 'fail' ERR
  log "Remove any existing PV data for kong-db"
  source setup-pv.sh clean pv kong-db $ACUMOS_NAMESPACE
  log "Setup the kong-db PV"
  source setup-pv.sh setup pv kong-db \
    $ACUMOS_NAMESPACE $KONG_DB_PV_SIZE "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
}

function prepare_nexus() {
  trap 'fail' ERR
  if [[ "$ACUMOS_DEPLOY_NEXUS" == "true" ]]; then
    log "Remove any existing PV data for nexus-data"
    source setup-pv.sh clean pv nexus-data $ACUMOS_NAMESPACE
    log "Setup the nexus-data PV"
    source setup-pv.sh setup pv nexus-data \
      $ACUMOS_NAMESPACE $NEXUS_DATA_PV_SIZE "200:$ACUMOS_HOST_USER"
  fi
}

function prepare_elk() {
  trap 'fail' ERR

  if [[ -e elk-env.sh ]]; then
    source elk-env.sh
    echo "source elk-env.sh" >>acumos-env.sh
  else
    if [[ "$ACUMOS_DEPLOY_ELK" == "true" ]]; then
      source ../charts/elk-stack/setup-elk-env.sh
      if [[ $($k8s_cmd delete $k8s_nstype $ACUMOS_ELK_NAMESPACE) ]]; then
        # Deleting namespace deletes all ELK services, deployments, PVCs, ...
        while $k8s_cmd get $k8s_nstype $ACUMOS_ELK_NAMESPACE; do
          log "Waiting 10 seconds for namespace $ACUMOS_ELK_NAMESPACE to be deleted"
          sleep 10
        done
      fi
      log "Remove any existing PV data for elasticsearch-data"
      source setup-pv.sh clean pv elasticsearch-data $ACUMOS_ELK_NAMESPACE
      log "Setup the elasticsearch-data PV"
      source setup-pv.sh setup pv elasticsearch-data \
        $ACUMOS_ELK_NAMESPACE $ACUMOS_ELASTICSEARCH_DATA_PV_SIZE "1000:1000"
    fi
  fi
}

function prepare_env() {
  trap 'fail' ERR
  source acumos-env.sh
  source utils.sh
  get_host_info
  export WORK_DIR=$(pwd)
  sed -i -- "s/DEPLOY_RESULT=.*/DEPLOY_RESULT=/" acumos-env.sh
  sed -i -- "s/FAIL_REASON=.*/FAIL_REASON=/" acumos-env.sh
  update_env AIO_ROOT $WORK_DIR
  update_env DEPLOYED_UNDER $1 force
  update_env ACUMOS_DOMAIN $2 force
  update_env ACUMOS_HOST_USER $3 force
  update_env ACUMOS_HOST $(hostname) force

  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    if [[ $(which oc) ]]; then
      k8s_cmd=oc
      k8s_nstype=project
    else
      k8s_cmd=kubectl
      k8s_nstype=namespace
    fi
  fi

  if [[ "$ACUMOS_HOST_IP" == "" ]]; then
    log "Determining host IP address for $ACUMOS_DOMAIN"
    if [[ $(host $ACUMOS_DOMAIN | grep -c 'not found') -eq 0 ]]; then
      update_env ACUMOS_HOST_IP $(host $ACUMOS_DOMAIN | head -1 | cut -d ' ' -f 4)
    elif [[ $(grep -c -P " $ACUMOS_DOMAIN( |$)" /etc/hosts) -gt 0 ]]; then
      update_env ACUMOS_HOST_IP $(grep -P "$ACUMOS_DOMAIN( |$)" /etc/hosts | cut -d ' ' -f 1)
    else
      log "Please ensure $ACUMOS_DOMAIN is resolvable thru DNS or hosts file"
      fail "IP address of $ACUMOS_DOMAIN cannot be determined."
    fi
  fi

  # Local variables used here and in other sourced scripts
  export HOST_OS=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
  export HOST_OS_VER=$(grep -m 1 'VERSION_ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')

  update_env ACUMOS_HOST_OS $HOST_OS
  update_env ACUMOS_HOST_OS_VER $HOST_OS_VER
  update_env ACUMOS_HOST_USER $USER

  hostip=$(/sbin/ip route get 8.8.8.8 | head -1 | sed 's/^.*src //' | awk '{print $1}')
  update_env ACUMOS_ADMIN_HOST $hostip
  source acumos-env.sh
}

set -x
prepare_env $1 $2 $3
trap 'fail' ERR
setup_prereqs

if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
  setup_docker
fi
log "Add $ACUMOS_HOST_USER to the docker group"
sudo usermod -G docker $ACUMOS_HOST_USER

install_mariadb_client
setup_keystore
prepare_mariadb
prepare_docker_engine
prepare_acumos
prepare_kong
prepare_nexus
prepare_elk

set +x
log "Prerequisites setup is complete."
if [[ -e /tmp/json ]]; then sudo rm /tmp/json; fi
if [[ -e /tmp/acumos ]]; then sudo rm -rf /tmp/acumos; fi
