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
# - acumos-env.sh script prepared through oneclick_deploy.sh or manually, to
#   set install options (e.g. docker/k8s)
# - host folder /var/$ACUMOS_NAMESPACE/certs created through setup-pv.sh
#
# Usage: intended to be called directly from oneclick_deploy.sh
#

function update_cert_env() {
  trap 'fail' ERR
  log "Updating acumos-env.sh with \"export $1=$2\""
  sed -i -- "s/$1=.*/$1=$2/" $AIO_ROOT/acumos-env.sh
  export $1=$2
}

function setup() {
  trap 'fail' ERR
  cd certs
  if [[ -e $ACUMOS_CERT ]]; then
    log "Using existing user-prepared files in certs subfolder"
  else
    log "Creating new certs in certs subfolder"
    source setup-certs.sh $ACUMOS_CERT_PREFIX $ACUMOS_DOMAIN
  fi

  if [[ ! -e cert-env.sh ]]; then
    log "Please ensure that cert-env.sh is in the certs folder"
    fail "cert-env.sh not found"
  fi
  source cert-env.sh
  update_cert_env ACUMOS_CERT_KEY_PASSWORD $CERT_KEY_PASSWORD
  update_cert_env ACUMOS_KEYSTORE_PASSWORD $KEYSTORE_PASSWORD
  update_cert_env ACUMOS_TRUSTSTORE_PASSWORD $TRUSTSTORE_PASSWORD
  cd ..

  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
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

setup
