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
# What this is: Script used by a host admin to prepare a host for a non-sudo
# user to later deploy/manage the Acumos platform there, under generic k8s.
# Deploys an instance of MariaDB and the ELK stack in their own k8s namespaces,
# and prepares other host prereqisites such as packages, config, and persistent
# volumes (PVs).
#
# Prerequisites:
# - Ubuntu Xenial/Bionic or Centos 7 server
# - Initial basic setup (manual), assuming the non-sudo user is "acumos"
#   sudo useradd -m acumos
# - User running this script has:
#   - Installed docker per system-integration/tools/setup_docker.sh
#   - Added themselves to the docker group (sudo usermod -G docker $USER)
#   - Logged out and back in, to activate docker group membership
# - cd to your home folder, as the root of this installation process
# - create subfolders "acumos" and folders "env", "logs", "certs"
# - If you want to use a specific/updated/patched system-integration repo clone,
#   place that system-integration clone in the home folder
# - Then run the command below
#
# Usage:
# $ bash system-integration/AIO/acumos_k8s_prep.sh <user> <domain> [clone]
#   user: non-sudo user account
#   domain: domain name of Acumos platorm (resolves to this host)
#   clone: if "clone", the current system-integration repo will be cloned.
#     Otherwise place the system-integration version to be used in folder
#     system-integration
#

set -x -e

if [[ $# -lt 2 ]]; then
  cat <<'EOF'
Usage:
  $ bash system-integration/AIO/acumos_k8s_prep.sh <user> <domain> [clone]
    user: non-sudo user account
    domain: domain name of Acumos platorm (resolves to this host)
    clone: if "clone", the current system-integration repo will be cloned.
      Otherwise place the system-integration version to be used in folder
      system-integration
EOF
  echo "All parameters not provided"
  exit 1
fi

export WORK_DIR=$(pwd)
export ACUMOS_HOST_USER=$1
export ACUMOS_DOMAIN=$2
clone=$3
export AIO_ROOT=$WORK_DIR/system-integration/AIO
export ACUMOS_NAMESPACE=acumos
export DEPLOYED_UNDER=k8s

if [[ $(bash --version | grep -c redhat-linux) -gt 0 ]]; then
  HOST_OS=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
  HOST_OS_VER=$(grep -m 1 'VERSION_ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
elif [[ $(bash --version | grep -c pc-linux) -gt 0 ]]; then
  HOST_OS=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
  HOST_OS_VER=$(grep -m 1 'VERSION_ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
else
  fail "Sorry, only Ubuntu or Centos is supported."
fi

if [[ "$HOST_OS" == "centos" ]]; then
  export K8S_DIST=openshift
  k8s_cmd=oc
  k8s_nstype=project
else
  export K8S_DIST=generic
  k8s_cmd=kubectl
  k8s_nstype=namespace
fi

mkdir -p $WORK_DIR/acumos/env $WORK_DIR/acumos/logs $WORK_DIR/acumos/certs

if [[ "$clone" == "clone" ]]; then
  if [[ -d system-integration ]]; then rm -rf system-integration; fi
  git clone https://gerrit.acumos.org/r/system-integration
fi

source $AIO_ROOT/utils.sh

# clean current environment
if [[ "$K8S_DIST" == "openshift" ]]; then
  wget -O cleanup.sh \
    https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/cleanup.sh
  bash cleanup.sh
  sudo yum erase -y docker-ce docker docker-engine docker.io
else
  if [[ $(which kubeadm) ]]; then
    sudo kubeadm reset -f
    # Per https://github.com/cloudnativelabs/kube-router/issues/383 - coredns will
    # stay in "containerCreating" if it comes up before calico is ready
    sudo rm -rf /var/lib/cni/networks/k8s-pod-network/*
  fi
  sudo apt-get purge -y docker-ce docker docker-engine docker.io
fi
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
if [[ ! $(sudo rm -rf /mnt/$ACUMOS_NAMESPACE/docker) ]]; then
  echo "Warning: all docker data could not be deleted"
fi
sudo rm -rf /mnt/$ACUMOS_NAMESPACE/*

# k8s setup
# use a specific folder for this, to prevent errors in removing system-integration
# on subsequent deployments (e.g. to re-clone or patch an existing clone)
if [[ -e k8s-deploy ]]; then
  while ! sudo rm -rf k8s-deploy; do
    echo "Unable to remove k8s-deploy... waiting 10 seconds"
    sleep 10
  done
fi
mkdir k8s-deploy
cd k8s-deploy
if [[ "$K8S_DIST" == "openshift" ]]; then
  bash $WORK_DIR/system-integration/tools/setup_openshift.sh
  bash $WORK_DIR/system-integration/tools/setup_helm.sh
  cd $WORK_DIR/system-integration/tools
  bash setup_prometheus.sh
else
  bash $WORK_DIR/system-integration/tools/setup_k8s.sh
  bash $WORK_DIR/system-integration/tools/setup_helm.sh
  cd $WORK_DIR/system-integration/tools
  bash setup_prometheus.sh
  secret=$($k8s_cmd get secrets | grep -m1 ^default-token | cut -f1 -d ' ')
  token=$($k8s_cmd describe secret $secret | grep -E '^token' | cut -f2 -d':' | tr -d " ")
  echo "Token for setting up the k8s dashboard at https://$ACUMOS_DOMAIN:32767"
  echo $token
fi

# Setup utility PVs for components that do not expect namespace or storageClass
pvs="pv-001 pv-002 pv-003 pv-004 pv-005"
for pv in $pvs; do
  if [[ ! $($k8s_cmd get pv $pv) ]]; then
    bash $WORK_DIR/system-integration/tools/setup_pv.sh setup $HOSTNAME $USER \
     $pv /mnt/$ACUMOS_NAMESPACE 5Gi
  fi
done

# Workaround for PVs getting stuck in "released" or "failed"
pvs=$($k8s_cmd get pv | grep -e 'Failed' -e 'Released' | awk '{print $1}')
for pv in $pvs ; do
  $k8s_cmd patch pv $pv --type json -p '[{ "op": "remove", "path": "/spec/claimRef" }]'
done

# mariadb setup
cd $AIO_ROOT
update_env AIO_ROOT $(pwd) force
update_env DEPLOYED_UNDER k8s force
update_env K8S_DIST $K8S_DIST force
export ACUMOS_HOST_IP=$(/sbin/ip route get 8.8.8.8 | head -1 | sed 's/^.*src //' | awk '{print $1}')
update_env ACUMOS_HOST_IP $ACUMOS_HOST_IP force
if [[ -e mariadb_env.sh ]]; then
  source mariadb_env.sh
else
  bash $WORK_DIR/system-integration/charts/mariadb/setup_mariadb_env.sh
fi
if [[ -e mariadb_env.sh ]]; then source mariadb_env.sh; fi
if [[ $(helm delete --purge mariadb) ]]; then
  echo "Helm release mariadb deleted"
fi
# Have to remove namespace and PVC in order for PV to be releasable
delete_namespace $ACUMOS_MARIADB_NAMESPACE
delete_pvc mariadb-data $ACUMOS_MARIADB_NAMESPACE
reset_pv mariadb-data $ACUMOS_MARIADB_NAMESPACE \
    $MARIADB_DATA_PV_SIZE "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
bash $WORK_DIR/system-integration/charts/mariadb/setup_mariadb.sh \
  $AIO_ROOT $(hostname) $K8S_DIST
cp $WORK_DIR/system-integration/charts/mariadb/mariadb_env.sh $WORK_DIR/acumos/env/.
cd $AIO_ROOT
cp $WORK_DIR/system-integration/charts/mariadb/mariadb_env.sh .
update_env ACUMOS_SETUP_DB false

# elk setup
cd $AIO_ROOT
if [[ -e elk_env.sh ]]; then
  source elk_env.sh
else
  cat <<EOF >$WORK_DIR/system-integration/charts/elk-stack/elk_env.sh
export ACUMOS_ELK_DOMAIN=$ACUMOS_DOMAIN
export ACUMOS_ELK_HOST=$(hostname)
EOF
fi
# Have to remove namespace and PVC in order for PV to be releasable
source $WORK_DIR/system-integration/charts/elk-stack/setup_elk_env.sh
if [[ $(helm delete --purge elk) ]]; then
  echo "Helm release elk deleted"
fi
delete_namespace $ACUMOS_ELK_NAMESPACE
delete_pvc elasticsearch-data $ACUMOS_ELK_NAMESPACE
reset_pv elasticsearch-data $ACUMOS_ELK_NAMESPACE \
  $ACUMOS_ELASTICSEARCH_DATA_PV_SIZE "1000:1000"
bash $WORK_DIR/system-integration/charts/elk-stack/setup_elk.sh $AIO_ROOT \
  $K8S_DIST
cp $WORK_DIR/system-integration/charts/elk-stack/elk_env.sh $WORK_DIR/acumos/env/.
cp $WORK_DIR/system-integration/charts/elk-stack/elk_env.sh $AIO_ROOT/.

# Install the prerequisites
cd $AIO_ROOT
update_env ACUMOS_NAMESPACE $ACUMOS_NAMESPACE force
update_env ACUMOS_DEPLOY_MARIADB false force
update_env ACUMOS_DEPLOY_ELK false force
if [[ -e $WORK_DIR/acumos/certs/*.p12 ]]; then
  update_env ACUMOS_CREATE_CERTS false force
  cp -r $WORK_DIR/acumos/certs .
else
  update_env ACUMOS_CREATE_CERTS true force
fi
cp $WORK_DIR/acumos/env/mariadb_env.sh .
cp $WORK_DIR/acumos/env/elk_env.sh .
bash setup_prereqs.sh k8s $ACUMOS_DOMAIN \
  $ACUMOS_HOST_USER $K8S_DIST
cd $WORK_DIR
