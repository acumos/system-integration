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
# user to later deploy/manage the Acumos platform there, under generic k8s
#
# Prerequisites:
# - Ubuntu Xenial/Bionic or Centos 7 server
# - Initial basic setup (manual), assuming the non-sudo user is "acumos"
#   sudo useradd -m acumos
#   mkdir -p ~/acumos/env
#   mkdir -p ~/acumos/logs
#   mkdir -p ~/acumos/certs
#   sudo cp -r ~/acumos /home/acumos/.
#   sudo chown -R acumos:acumos /home/acumos/acumos
#   # Put any pre-prepared certs into ~/acumos/certs
#
# Usage:
# - bash acumos_k8s_prep.sh <user> <domain> [clone]
#   user: non-sudo user account
#   domain: domain name of Acumos platorm (resolves to this host)
#   clone: if "clone", the current system-integration repo will be cloned.
#     Otherwise place the system-integration version to be used at
#     ~/system-integration
#

function prep_fail() {
  exit 1
}

set -x
trap 'prep_fail' ERR

export ACUMOS_HOST_USER=$1
export ACUMOS_DOMAIN=$2
clone=$3
export DEPLOYED_UNDER=k8s
export K8S_DIST=generic
export ACUMOS_NAMESPACE=acumos

source ~/system-integration/AIO/utils.sh

if [[ "$clone" == "clone" ]]; then
  if [[ -d system-integration ]]; then rm -rf system-integration; fi
  git clone https://gerrit.acumos.org/r/system-integration
fi

# k8s setup
# Use "sudo kubeadm reset" to re-execute the steps below on next deploy
if [[ ! $(kubectl get nodes) ]]; then
  cd ~/system-integration/tools
  bash setup_k8s.sh
  bash setup_helm.sh
  bash setup_prometheus.sh
  secret=$(kubectl get secrets | grep -m1 ^default-token | cut -f1 -d ' ')
  token=$(kubectl describe secret $secret | grep -E '^token' | cut -f2 -d':' | tr -d " ")
  echo "Token for setting up the k8s dashboard at https://$ACUMOS_DOMAIN:32767"
  echo $token
fi

pvs="pv-001 pv-002 pv-003 pv-004 pv-005"
for pv in $pvs; do
  reset_pv $pv $ACUMOS_NAMESPACE 10Gi "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
done
# Workaround for PVs getting stuck in "released" or "failed"
pvs=$(kubectl get pv | grep -e 'Failed' -e 'Released' | awk '{print $1}')
for pv in $pvs ; do
  kubectl patch pv $pv --type json -p '[{ "op": "remove", "path": "/spec/claimRef" }]'
done

# mariadb setup
cd ~/system-integration/charts/mariadb
export ACUMOS_HOST_IP=$(/sbin/ip route get 8.8.8.8 | head -1 | sed 's/^.*src //' | awk '{print $1}')
source setup-mariadb-env.sh
if [[ $(helm delete --purge mariadb) ]]; then
  echo "Helm release mariadb deleted"
fi
# Have to remove namespace and PVC in order for PV to be releasable
delete_namespace $ACUMOS_MARIADB_NAMESPACE
delete_pvc mariadb-data $ACUMOS_MARIADB_NAMESPACE
reset_pv mariadb-data $ACUMOS_MARIADB_NAMESPACE \
    $MARIADB_DATA_PV_SIZE "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
stamp=$(date +"%y%m%d-%H%M%S")
log="mariadb-$stamp.log"
source setup-mariadb.sh $(hostname) generic 2>&1 | tee ~/acumos/logs/$log
cp mariadb-env.sh ~/acumos/env/.

# elk setup
source ~/acumos/env/mariadb-env.sh
cd ~/system-integration/charts/elk-stack
cat <<EOF >elk-env.sh
export ACUMOS_ELK_DOMAIN=$ACUMOS_DOMAIN
export ACUMOS_ELK_HOST=$(hostname)
EOF
# Have to remove namespace and PVC in order for PV to be releasable
source elk-env.sh
source setup-elk-env.sh
if [[ $(helm delete --purge elk) ]]; then
  echo "Helm release elk deleted"
fi
delete_namespace $ACUMOS_ELK_NAMESPACE
delete_pvc elasticsearch-data $ACUMOS_ELK_NAMESPACE
reset_pv elasticsearch-data $ACUMOS_ELK_NAMESPACE \
  $ACUMOS_ELASTICSEARCH_DATA_PV_SIZE "1000:1000"
stamp=$(date +"%y%m%d-%H%M%S")
log="elk-$stamp.log"
source setup-elk.sh generic 2>&1 | tee ~/acumos/logs/$log
cp elk-env.sh ~/acumos/env/.

# Install the prerequisites
cd ~/system-integration/AIO
sed -i -- "s/ACUMOS_DEPLOY_MARIADB=true/ACUMOS_DEPLOY_MARIADB=false/" acumos-env.sh
sed -i -- "s/ACUMOS_DEPLOY_ELK=true/ACUMOS_DEPLOY_ELK=false/" acumos-env.sh
sed -i -- "s/ACUMOS_CREATE_CERTS=.*/ACUMOS_CREATE_CERTS=false/" acumos-env.sh
cp ~/acumos/env/mariadb-env.sh .
cp ~/acumos/env/elk-env.sh .
cp -r ~/acumos/certs .
stamp=$(date +%y%m%d-%H%M%S)
log="aio_k8s_prep-$stamp.log"
bash setup_prereqs.sh k8s $ACUMOS_DOMAIN \
  $ACUMOS_HOST_USER generic 2>&1 | tee ~/acumos/logs/$log
sudo chown -R $ACUMOS_HOST_USER:$ACUMOS_HOST_USER /var/$ACUMOS_NAMESPACE/*
cp acumos-env.sh ~/acumos/env/.

if [[ "$ACUMOS_HOST_USER" != "$USER" ]]; then
  # Setup the acumos user env
  sudo cp -R ~/.kube /home/$ACUMOS_HOST_USER/.
  sudo chown -R $ACUMOS_HOST_USER:$ACUMOS_HOST_USER /home/$ACUMOS_HOST_USER/.kube
  sudo cp ~/$ACUMOS_HOST_USER/env/*-env.sh /home/$ACUMOS_HOST_USER/acumos/env/.
  sudo chown $ACUMOS_HOST_USER:$ACUMOS_HOST_USER /home/$ACUMOS_HOST_USER/acumos/env/*
fi
