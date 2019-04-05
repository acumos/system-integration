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
# What this is: script that enables use of pre-configured CA and server
# certificates for an Acumos platform, or creation of new self-signed
# certificates.
#
# Prerequisites:
# - acumos_env.sh script prepared through oneclick_deploy.sh or manually, to
#   set install options (e.g. docker/k8s)
# - host folder /mnt/$ACUMOS_NAMESPACE/certs created through setup_pv.sh
#
# Usage:
#   For docker-based deployments, run this script on the AIO host.
#   For k8s-based deployment, run this script on the AIO host or a workstation
#   connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
#   $ bash setup_keystore.sh <AIO_ROOT>
#     AIO_ROOT: path to AIO folder where environment files are
#

function update_cert_env() {
  trap 'fail' ERR
  log "Updating acumos_env.sh with \"export $1=$2\""
  sedi "s/$1=.*/$1=$2/" $AIO_ROOT/acumos_env.sh
  export $1=$2
}

function setup_keystore() {
  trap 'fail' ERR
  if [[ -e certs/$ACUMOS_CERT ]]; then
    log "Using existing user-prepared files in certs subfolder"
  else
    log "Creating new certs in certs subfolder"
    bash certs/setup_certs.sh $AIO_ROOT $ACUMOS_CERT_PREFIX $ACUMOS_DOMAIN
  fi

  if [[ ! -e certs/cert_env.sh ]]; then
    log "Please ensure that cert_env.sh is in the certs folder"
    fail "cert_env.sh not found"
  fi
  source certs/cert_env.sh
  update_cert_env ACUMOS_CERT_KEY_PASSWORD $CERT_KEY_PASSWORD
  update_cert_env ACUMOS_KEYSTORE_PASSWORD $KEYSTORE_PASSWORD
  update_cert_env ACUMOS_TRUSTSTORE_PASSWORD $TRUSTSTORE_PASSWORD

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    if [[ ! -e /mnt/$ACUMOS_NAMESPACE/certs ]]; then
      log "Create /mnt/$ACUMOS_NAMESPACE/certs as cert storage folder"
      sudo mkdir -p /mnt/$ACUMOS_NAMESPACE/certs
      # Have to set user and group to allow pod access to PVs
      sudo chown $ACUMOS_HOST_USER:$ACUMOS_HOST_USER /mnt/$ACUMOS_NAMESPACE
      sudo chown $ACUMOS_HOST_USER:$ACUMOS_HOST_USER /mnt/$ACUMOS_NAMESPACE/certs
    fi
    cp $(ls certs/* | grep -v '\.sh') /mnt/$ACUMOS_NAMESPACE/certs/.
  else
    log "Create kubernetes configmap to hold the keystore and truststore"
    # See use in deployment templates for portal-be and federation
    if [[ $(kubectl get configmap -n $ACUMOS_NAMESPACE acumos-store) ]]; then
      log "Delete existing acumos-certs configmap in case cert changes were made"
      kubectl delete configmap -n $ACUMOS_NAMESPACE acumos-store
    fi
    kubectl create configmap -n $ACUMOS_NAMESPACE acumos-store \
      --from-file=certs/$ACUMOS_KEYSTORE,certs/$ACUMOS_TRUSTSTORE
  fi
}

if [[ $# -lt 1 ]]; then
  echo <<'EOF'
Usage:
  For docker-based deployments, run this script on the AIO host.
  For k8s-based deployment, run this script on the AIO host or a workstation
  connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
  $ bash setup_keystore.sh <AIO_ROOT>
    AIO_ROOT: path to AIO folder where environment files are
EOF
  echo "All parameters not provided"
  exit 1
fi

WORK_DIR=$(pwd)
export AIO_ROOT=$1
source $AIO_ROOT/acumos_env.sh
source $AIO_ROOT/utils.sh
trap 'fail' ERR
cd $AIO_ROOT
setup_keystore
cd $WORK_DIR
