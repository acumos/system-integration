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
# - All hostnames specified in acumos_env.sh must be DNS-resolvable on all hosts
#   (entries in /etc/hosts or in an actual DNS server)
# - For deployments behind proxies, set HTTP_PROXY and HTTPS_PROXY in acumos_env.sh
# - Initial basic setup (manual), assuming the non-sudo user is "acumos"
#   sudo useradd -m acumos
# - User running this script has:
#   - Installed docker per system-integration/tools/setup_docker.sh
#   - Added themselves to the docker group (sudo usermod -aG docker $USER)
#   - Logged out and back in, to activate docker group membership
# - cd to your home folder, as the root of this installation process
# - If you want to use a specific/updated/patched system-integration repo clone,
#   place that system-integration clone in the home folder
# - Then run the command below
#
# Usage:
# $ bash system-integration/AIO/acumos_k8s_prep.sh <user> <domain>
#   user: non-sudo user account
#   domain: domain name of Acumos platorm (resolves to this host)
#

function clean_k8s() {
  trap 'fail' ERR
  bash $WORK_DIR/system-integration/tools/setup_k8s_stack.sh clean
  sudo rm -rf /mnt/$ACUMOS_NAMESPACE/docker && true
  if [[ -e /mnt/$ACUMOS_NAMESPACE/docker ]]; then
    echo "Warning: all docker data could not be deleted"
    if [[ "$K8S_DIST" == "openshift" ]]; then
      # Retrying this can resolve issues with resources under OpenShift deploys
      bash cleanup.sh
    fi
  fi
  sudo rm -rf /mnt/$ACUMOS_NAMESPACE/* && true
}

function prep_k8s() {
  trap 'fail' ERR
  bash $WORK_DIR/system-integration/tools/setup_k8s_stack.sh setup

  log "Setup utility PVs for components that do not expect namespace or storageClass"
  sizes="1Gi 5Gi 10Gi"
  for size in $sizes; do
    pvs="001 002 003 004 005"
    for pv in $pvs; do
      if [[ ! $(kubectl get pv $pv) ]]; then
        bash $WORK_DIR/system-integration/tools/setup_pv.sh setup $HOSTNAME $USER \
         pv-$(echo "$size" | awk '{print tolower($0)}')-$pv /mnt/$ACUMOS_NAMESPACE $size
      fi
    done
  done
}

if [[ $# -lt 2 ]]; then
  cat <<'EOF'
Usage:
  $ bash system-integration/AIO/acumos_k8s_prep.sh <user> <domain>
    user: non-sudo user account
    domain: domain name of Acumos platorm (resolves to this host)
EOF
  echo "All parameters not provided"
  exit 1
fi

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
source utils.sh
verify_ubuntu_or_centos
update_env AIO_ROOT $(pwd) force
update_env ACUMOS_HOST_USER $1 force
update_env ACUMOS_DOMAIN $2 force
update_env DEPLOYED_UNDER k8s force
update_env K8S_DIST $K8S_DIST force
export ACUMOS_HOST_IP=$(/sbin/ip route get 8.8.8.8 | head -1 | sed 's/^.*src //' | awk '{print $1}')
update_env ACUMOS_HOST_IP $ACUMOS_HOST_IP force
get_host_ip $ACUMOS_DOMAIN
update_env ACUMOS_DOMAIN_IP $ACUMOS_DOMAIN_IP force
source acumos_env.sh
mkdir -p $WORK_DIR/acumos/env $WORK_DIR/acumos/logs $WORK_DIR/acumos/certs
if [[ "$(grep 'ACUMOS_NAMESPACE=' acumos_env.sh | cut -d '=' -f 2)" == "" ]]; then
  update_env ACUMOS_NAMESPACE acumos force
else
  export ACUMOS_NAMESPACE=$(grep 'ACUMOS_NAMESPACE=' acumos_env.sh | cut -d '=' -f 2)
fi

if [[ $(kubectl get namespace kube-system | grep -c Active) -eq 0 || "$USE_EXISTING_K8S_CLUSTER" != "true" ]]; then
  clean_k8s
  prep_k8s
fi

bash $WORK_DIR/system-integration/charts/mariadb/setup_mariadb.sh \
  $(hostname) $K8S_DIST prep
cp $AIO_ROOT/mariadb_env.sh $WORK_DIR/acumos/env/.
update_env ACUMOS_DEPLOY_MARIADB false force

bash $WORK_DIR/system-integration/charts/elk-stack/setup_elk.sh \
  $(hostname) $K8S_DIST prep
update_env ACUMOS_DEPLOY_ELK false force
cp $AIO_ROOT/elk_env.sh $WORK_DIR/acumos/env/.

cd $AIO_ROOT
if [[ -e $WORK_DIR/acumos/certs/*.p12 ]]; then
  update_env ACUMOS_CREATE_CERTS false force
  cp -r $WORK_DIR/acumos/certs .
else
  update_env ACUMOS_CREATE_CERTS true force
fi
bash setup_prereqs.sh k8s $ACUMOS_DOMAIN $ACUMOS_HOST_USER $K8S_DIST
cd $WORK_DIR
