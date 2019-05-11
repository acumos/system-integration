#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2018 AT&T Intellectual Property. All rights reserved.
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
# What this is: Setup script for an OpenShift kubernetes cluster.
#
# Prerequisites:
# - Centos 7 server
#
# Usage: on the node to become the master
# $ bash setup_openshift.sh "[nodes]"
#   nodes: quoted, space-separated list of k8s worker nodes. If no nodes are
#          specified a single all-in-one cluster will be installed

function setup_prereqs() {
  log "Create prerequisite setup script"
  cat <<'EOG' >~/prereqs.sh
#!/bin/bash
# Basic server pre-reqs
if [[ $(grep -c $HOSTNAME /etc/hosts) -eq 0 ]]; then
  echo; echo "prereqs.sh: ($(date)) Add $HOSTNAME to /etc/hosts"
  # have to add "/sbin" to path of IP command for centos
  echo "$(/sbin/ip route get 8.8.8.8 | head -1 | sed 's/^.*src //' | awk '{print $1}') $HOSTNAME" \
    | sudo tee -a /etc/hosts
fi
echo; echo "prereqs.sh: ($(date)) Basic prerequisites"
sudo yum install -y epel-release
sudo yum update -y
sudo yum install -y wget git
if [[ "$(rpm -qa | grep docker-1)" != "" ]]; then
  echo; echo "Remove prior docker install"
  sudo yum remove -y docker docker-common
fi
echo; echo "prereqs.sh: ($(date)) Install latest docker-ce"
# https://docs.okd.io/3.11/install/host_preparation.html#installing-docker
# per https://docs.docker.com/engine/installation/linux/docker-ce/centos/#install-from-a-package
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce
sudo systemctl enable docker
sudo systemctl start docker
EOG
}

function setup_master() {
  trap 'fail' ERR
  log "Setup master"
  bash ~/prereqs.sh
  # Per https://github.com/openshift/origin
  log "Install OpenShift Origin"
  log "Prepare docker config to support OpenShift local docker registry"
  # Per https://docs.okd.io/latest/install/host_preparation.html#install-config-install-host-preparation
  cat << EOF | sudo tee /etc/docker/daemon.json
{
  "insecure-registries": [
    "172.30.0.0/16"
  ]
}
EOF
  sudo systemctl restart docker

  log "Install openshift-ansible"
  # Per https://github.com/openshift/openshift-ansible
  sudo yum install -y ansible pyOpenSSL python-cryptography python-lxml
  sudo yum install -y java-1.8.0-openjdk-headless
  sudo yum install -y patch
  sudo yum install -y httpd-tools

  log "Download the OpenShift binaries from GitHub"
  wget https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz
  tar -xf openshift-origin-client-tools-*.tar.gz
  cd openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit
  if [[ -e /usr/bin/kubectl ]]; then sudo rm /usr/bin/kubectl; fi
  if [[ -e /usr/bin/oc ]]; then sudo rm /usr/bin/oc; fi
  sudo mv kubectl oc /usr/bin/.
  log "Bring up the all-in-one cluster"
  # Add --public-hostname="$(hostname)" so you can browse the console!
  sudo /usr/bin/oc cluster up --public-hostname="$(hostname)"

  # Copy the kube config created as root due to use of sudo
  # TODO: option to set ansible_ssh_user in inventory file to avoid root use
  cd ~
  sudo cp -r /root/.kube ~/.
  sudo chown -R $USER ~/.kube/*

  log "Additional cluster admin setup steps"
  # Per https://docs.okd.io/latest/getting_started/administrators.html

  log "Setup kube config and add cluster-admin role for 'admin' user"
  oc login -u admin -p any
  oc logout
  oc login -u system:admin
  oc adm policy add-cluster-role-to-user cluster-admin admin

  log "Start OpenShift local docker registry service"
  oc adm registry

  log "All done!"
  echo "Login as user admin (any password) at https://$(hostname):8443"
  echo "If you will access this cluster from another machine (e.g. workstation)"
  echo "you can now run setup_client.sh on that machine to setup remote access"
}

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ../AIO; pwd -P)"; fi
source $AIO_ROOT/utils.sh
cd $WORK_DIR
workers="$1"
setup_prereqs
setup_master
