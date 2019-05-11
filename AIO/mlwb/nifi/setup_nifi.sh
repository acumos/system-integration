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
# What this is: Deployment script for NiFi, adding Acumos customizations.
#
# Prerequisites:
# - Kubernetes cluster deployed
# - Make sure there are at least 6 free PVs for nifi, e.g. by running
#   system-integration/tools/setup_pv.sh setup <master> <username> <name> <path> 10Gi standard
#   "standard" is the required storage class.
#
# Usage:
# $ bash setup_nifi.sh <AIO_ROOT>
#   AIO_ROOT: path to AIO folder where environment files are

clean_nifi() {
  trap 'fail' ERR

  log "Stop any existing k8s based components for NiFi"
  trap - ERR
  rm -rf deploy
  log "Delete all NiFi user resources"

  if [[ $($k8s_cmd delete deployment -n $ACUMOS_NAMESPACE nifi-registry) ]]; then
    log "deployment nifi-registry deleted"
  fi
  if [[ $($k8s_cmd delete service -n $ACUMOS_NAMESPACE nifi-registry-service) ]]; then
    log "service nifi-registry-service deleted"
  fi
  deps=$($k8s_cmd get pods -n $ACUMOS_NAMESPACE  | awk '/nifi/{print $1}')
  for dep in $deps; do
    $k8s_cmd delete deployment -n $ACUMOS_NAMESPACE $dep
  done
  svcs=$($k8s_cmd get svc -n $ACUMOS_NAMESPACE | awk '/nifi/{print $1}')
  for svc in $svcs; do
    $k8s_cmd delete svc -n $ACUMOS_NAMESPACE $svc
  done
  cfgs=$($k8s_cmd get configmap -n $ACUMOS_NAMESPACE | awk '/nifi/{print $1}')
  for cfg in $cfgs; do
    $k8s_cmd delete configmap -n $ACUMOS_NAMESPACE $cfg
  done
  ings=$($k8s_cmd get ingress -n $ACUMOS_NAMESPACE | awk '/nifi/{print $1}')
  for ing in $ings; do
    $k8s_cmd delete ingress -n $ACUMOS_NAMESPACE $ing
  done

  trap 'fail' ERR

  log "Delete cert, truststore, and keystore for nifi"
  if [[ -d certs ]]; then rm -rf certs; fi

  if [[ $($k8s_cmd delete secret -n $ACUMOS_NAMESPACE nifi-certs) ]]; then
    log "secret nifi-certs deleted"
  fi

  if [[ $($k8s_cmd delete configmap -n $ACUMOS_NAMESPACE nifi-registry-apache) ]]; then
    log "configmap nifi-registry-apache deleted"
  fi

  if [[ $($k8s_cmd delete configmap -n $ACUMOS_NAMESPACE nifi-templates) ]]; then
    log "configmap nifi-templates deleted"
  fi

  if [[ $($k8s_cmd delete pvc -n $ACUMOS_NAMESPACE nifi-templates) ]]; then
    log "nifi-registry PVC deleted"
  fi

  if [[ $($k8s_cmd delete rolebinding -n $ACUMOS_NAMESPACE namespace-admin) ]]; then
    log "namespace-admin rolebinding deleted"
  fi

  if [[ $($k8s_cmd delete role -n $ACUMOS_NAMESPACE namespace-admin) ]]; then
    log "namespace-admin role deleted"
  fi
}

setup_nifi() {
  trap 'fail' ERR
  log "Create cert, truststore, and keystore for nifi"
  # Per https://access.redhat.com/solutions/82363
  log "Create private key"
  openssl genrsa -out apache_key.pem 1024
  log "Create server cert based on private key"
  openssl req -new -key apache_key.pem -x509 -out apache_cert.pem -days 365 \
    -subj "/C=US/ST=Unspecified/L=Unspecified/O=acumos/OU=acumos/CN=$MLWB_NIFI_REGISTRY_INITIAL_ADMIN"
  log "Create combined private key and server cert file for Apache"
  cat apache_key.pem apache_cert.pem > apache_proxy.pem

  log "Create PKCS12 format keystore with server cert"
  if [[ -e nifi-keystore.jks ]]; then rm nifi-keystore.jks; fi
  KEYSTORE_PASSWORD=$(uuidgen)
  openssl pkcs12 -export \
    -in apache_cert.pem \
    -inkey apache_key.pem \
    -certfile apache_cert.pem \
    -out nifi-keystore.p12 \
    -passout pass:$KEYSTORE_PASSWORD

  log "Create JKS format truststore with CA cert"
  if [[ -e nifi-truststore.jks ]]; then rm nifi-truststore.jks; fi
  TRUSTSTORE_PASSWORD=$(uuidgen)
  keytool -import \
    -file apache_cert.pem \
    -alias nifi-ca \
    -keystore nifi-truststore.jks \
    -storepass $TRUSTSTORE_PASSWORD -noprompt

  $k8s_cmd create secret generic nifi-certs -n $ACUMOS_NAMESPACE -o yaml \
    --from-file=apache_proxy.pem,apache_cert.pem,nifi-truststore.jks,nifi-keystore.p12

  log "Update templates with environment variables"
  if [[ ! -d deploy ]]; then mkdir deploy; fi
  cp kubernetes/* deploy/.
  sedi "s/<ACUMOS_NAMESPACE>/$ACUMOS_NAMESPACE/g" deploy/nifi-registry-apache-configmap.yaml
  sedi "s/<ACUMOS_NAMESPACE>/$ACUMOS_NAMESPACE/g" deploy/nifi-registry-deployment.yaml
  sedi "s/<KEYSTORE_PASSWORD>/$KEYSTORE_PASSWORD/g" deploy/nifi-registry-deployment.yaml
  sedi "s/<TRUSTSTORE_PASSWORD>/$TRUSTSTORE_PASSWORD/g" deploy/nifi-registry-deployment.yaml
  sedi "s/<MLWB_NIFI_REGISTRY_INITIAL_ADMIN>/$MLWB_NIFI_REGISTRY_INITIAL_ADMIN/g" deploy/nifi-registry-deployment.yaml
  replace_env deploy/ingress-registry.yaml
  replace_env deploy/namespace-admin-role.yaml
  replace_env deploy/namespace-admin-rolebinding.yaml
  replace_env deploy/nifi-registry-service.yaml

  log "Create templates configmap for nifi"
  cp -r templates deploy/.
  replace_env deploy/templates/deployment.yaml
  replace_env deploy/templates/service.yaml
  replace_env deploy/templates/ingress.yaml
  sedi "s/<ACUMOS_NAMESPACE>/$ACUMOS_NAMESPACE/g" deploy/templates/apache_configmap.yaml
  sedi "s/<ACUMOS_NAMESPACE>/$ACUMOS_NAMESPACE/g" deploy/templates/nifi_configmap.yaml
  sedi "s/<KEYSTORE_PASSWORD>/$KEYSTORE_PASSWORD/g" deploy/templates/nifi_configmap.yaml
  sedi "s/<CERT_KEY_PASSWORD>/$CERT_KEY_PASSWORD/g" deploy/templates/nifi_configmap.yaml
  sedi "s/<TRUSTSTORE_PASSWORD>/$TRUSTSTORE_PASSWORD/g" deploy/templates/nifi_configmap.yaml
  $k8s_cmd create configmap nifi-templates -n $ACUMOS_NAMESPACE \
    --from-file=deploy/templates

  log "Create configmap nifi-registry-apache"
  $k8s_cmd create -f deploy/nifi-registry-apache-configmap.yaml

  log "Create NiFi Registry PVC in namespace $ACUMOS_NAMESPACE"
  setup_pvc nifi-registry $ACUMOS_NAMESPACE $MLWB_NIFI_REGISTRY_PV_SIZE

  log "Create NiFi Registry ingress"
  $k8s_cmd create -f deploy/ingress-registry.yaml

  log "Create NiFi Registry service and deployment"
  $k8s_cmd create -f deploy/nifi-registry-service.yaml
  $k8s_cmd create -f deploy/nifi-registry-deployment.yaml
  wait_running nifi-registry $ACUMOS_NAMESPACE

  log "Enable Pipeline Service to create NiFi user services under k8s"
  $k8s_cmd create -f deploy/namespace-admin-role.yaml
  $k8s_cmd create -f deploy/namespace-admin-rolebinding.yaml
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
clean_nifi
setup_nifi
cd $WORK_DIR
