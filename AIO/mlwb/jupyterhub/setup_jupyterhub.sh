#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2019 AT&T Intellectual Property. All rights reserved.
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
# What this is: Deployment script for jupyterhub, adding Acumos customizations. #
# Prerequisites:
# - Kubernetes cluster deployed
# - Make sure there are at least 6 free PVs for nifi, e.g. by running
#   system-integration/tools/setup_pv.sh setup <master> <username> <name> <path> 10Gi standard
#   "standard" is the required storage class.
#
# Usage:
# $ bash setup_jupyterhub.sh <AIO_ROOT>
#   AIO_ROOT: path to AIO folder where environment files are

setup_jupyterhub() {
  trap 'fail' ERR
  log "Create cert, truststore, and keystore for nifi"
  if [[ ! -d certs ]]; then mkdir certs; fi
  cd certs
  bash $AIO_ROOT/certs/setup_certs.sh $AIO_ROOT nifi localhost

  log "Create cert, truststore, and keystore for nifi"
  source cert_env.sh
  kubectl create secret generic nifi-cert -n $ACUMOS_NAMESPACE -o yaml \
    --from-file=nifi.crt,nifi-truststore.jks,nifi-keystore.p12
  cd ..

  log "Update templates with environment variables"
  if [[ ! -d deploy ]]; then mkdir deploy; fi
  cp templates/* deploy/.
  cp kubernetes/* deploy/.
  replace_env deploy

  log "Create NiFi Registry service and deployment"
  kubectl create -f deploy/nifi-registry-service.yaml
  kubectl create -f deploy/nifi-registry-deployment.yaml

  log "Enable Pipeline Service to create NiFi user services under k8s"
  kubectl create -f deploy/namespace-admin-role.yaml
  kubectl create -f deploy/namespace-admin-rolebinding.yaml
}

if [[ $# -lt 1 ]]; then
  cat <<'EOF'
Usage:
  $ bash setup_nifi.sh <AIO_ROOT>
    AIO_ROOT: path to AIO folder where environment files are
EOF
  echo "All parameters not provided"
  exit 1
fi

set -x
WORK_DIR=$(pwd)
export AIO_ROOT=$1
source $AIO_ROOT/acumos_env.sh
source $AIO_ROOT/utils.sh
cd $(dirname "$0")
trap 'fail' ERR
setup_jupyterhub
cd $WORK_DIR
