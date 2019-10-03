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
# $ bash setup_nifi.sh [setup|clean|all]
#  setup: setup NiFi components
#  clean: stop NiFi components
#  all: (default) stop and setup
#

clean_nifi() {
  trap 'fail' ERR

  log "Stop any existing k8s based components for NiFi"
  trap - ERR
  log "Delete all NiFi resources"
  clean_resource $ACUMOS_NAMESPACE deployment nifi
  clean_resource $ACUMOS_NAMESPACE replicaset nifi
  clean_resource $ACUMOS_NAMESPACE pods nifi
  clean_resource $ACUMOS_NAMESPACE service nifi
  clean_resource $ACUMOS_NAMESPACE configmap nifi
  clean_resource $ACUMOS_NAMESPACE secret nifi
  clean_resource $ACUMOS_NAMESPACE pvc nifi
  if [[ "$ACUMOS_DEPLOY_INGRESS" == "true" ]]; then
    clean_resource $ACUMOS_NAMESPACE ingress nifi
  fi
  trap 'fail' ERR

  log "Delete cert, truststore, and keystore for nifi"
  if [[ -d certs ]]; then rm -rf certs; fi

  if [[ $(kubectl delete rolebinding -n $ACUMOS_NAMESPACE namespace-admin) ]]; then
    log "namespace-admin rolebinding deleted"
  fi

  if [[ $(kubectl delete role -n $ACUMOS_NAMESPACE namespace-admin) ]]; then
    log "namespace-admin role deleted"
  fi
}

setup_nifi() {
  trap 'fail' ERR
  log "Create cert, truststore, and keystore for nifi"
  # Per https://access.redhat.com/solutions/82363
  log "Create password-protected private key"
  MLWB_NIFI_KEY_PASSWORD=$(uuidgen)
  export MLWB_NIFI_KEY_PASSWORD=$MLWB_NIFI_KEY_PASSWORD
  sedi "s/MLWB_NIFI_KEY_PASSWORD=.*/MLWB_NIFI_KEY_PASSWORD=$MLWB_NIFI_KEY_PASSWORD/" ../mlwb_env.sh
  openssl genrsa -des3 -out nifi_key.pem -passout pass:$MLWB_NIFI_KEY_PASSWORD

  log "Create NiFi server cert based on NiFi private key"
  openssl req -new -key nifi_key.pem -x509 -out nifi_cert.pem -days 365 \
    -passin pass:$MLWB_NIFI_KEY_PASSWORD \
    -subj "/C=US/ST=Unspecified/L=Unspecified/O=acumos/OU=acumos/CN=$MLWB_NIFI_REGISTRY_INITIAL_ADMIN"

  log "Export uprotected private key for use with Apache"
  openssl rsa -in nifi_key.pem \
    -passin pass:$MLWB_NIFI_KEY_PASSWORD \
    -out apache_key.pem

  log "Create Apache server cert based on Apache private key"
  openssl req -new -key apache_key.pem -x509 -out apache_cert.pem -days 365 \
    -subj "/C=US/ST=Unspecified/L=Unspecified/O=acumos/OU=acumos/CN=$MLWB_NIFI_REGISTRY_INITIAL_ADMIN"
  log "Create combined private key and server cert file for Apache"
  cat apache_key.pem apache_cert.pem > apache_proxy.pem

  log "Create PKCS12 format keystore with server cert"
  MLWB_NIFI_KEYSTORE_PASSWORD=$MLWB_NIFI_KEY_PASSWORD
  export MLWB_NIFI_KEYSTORE_PASSWORD=$MLWB_NIFI_KEYSTORE_PASSWORD
  sedi "s/MLWB_NIFI_KEYSTORE_PASSWORD=.*/MLWB_NIFI_KEYSTORE_PASSWORD=$MLWB_NIFI_KEYSTORE_PASSWORD/" ../mlwb_env.sh
  openssl pkcs12 -export \
    -in nifi_cert.pem \
    -inkey nifi_key.pem \
    -passin pass:$MLWB_NIFI_KEY_PASSWORD \
    -certfile nifi_cert.pem \
    -out nifi-keystore.p12 \
    -passout pass:$MLWB_NIFI_KEYSTORE_PASSWORD

  log "Create JKS format truststore with CA cert"
  if [[ -e nifi-truststore.jks ]]; then rm nifi-truststore.jks; fi
  MLWB_NIFI_TRUSTSTORE_PASSWORD=$MLWB_NIFI_KEY_PASSWORD
  export MLWB_NIFI_TRUSTSTORE_PASSWORD=$MLWB_NIFI_TRUSTSTORE_PASSWORD
  sedi "s/MLWB_NIFI_TRUSTSTORE_PASSWORD=.*/MLWB_NIFI_TRUSTSTORE_PASSWORD=$MLWB_NIFI_TRUSTSTORE_PASSWORD/" ../mlwb_env.sh
  keytool -import \
    -file apache_cert.pem \
    -alias nifi-ca \
    -keystore nifi-truststore.jks \
    -storepass $MLWB_NIFI_TRUSTSTORE_PASSWORD -noprompt

  kubectl create secret generic nifi-certs-registry -n $ACUMOS_NAMESPACE -o yaml \
    --from-file=apache_key.pem,apache_cert.pem,apache_proxy.pem,nifi_key.pem,nifi_cert.pem,nifi-truststore.jks,nifi-keystore.p12

  log "Update templates with environment variables"
  if [[ ! -e deploy ]]; then mkdir deploy; fi
  cp kubernetes/* deploy/.
  # Have to use sed since some files contain '<>' sequences that break replace_env
  sedi "s/<ACUMOS_NAMESPACE>/$ACUMOS_NAMESPACE/g" deploy/nifi-registry-apache-configmap.yaml
  sedi "s/<ACUMOS_NAMESPACE>/$ACUMOS_NAMESPACE/g" deploy/nifi-registry-deployment.yaml
  sedi "s/<MLWB_NIFI_KEY_PASSWORD>/$MLWB_NIFI_KEY_PASSWORD/g" deploy/nifi-registry-deployment.yaml
  sedi "s/<MLWB_NIFI_KEYSTORE_PASSWORD>/$MLWB_NIFI_KEYSTORE_PASSWORD/g" deploy/nifi-registry-deployment.yaml
  sedi "s/<MLWB_NIFI_TRUSTSTORE_PASSWORD>/$MLWB_NIFI_TRUSTSTORE_PASSWORD/g" deploy/nifi-registry-deployment.yaml
  sedi "s/<MLWB_NIFI_REGISTRY_INITIAL_ADMIN>/$MLWB_NIFI_REGISTRY_INITIAL_ADMIN/g" deploy/nifi-registry-deployment.yaml
  sedi "s~<MLWB_NIFI_REGISTRY_PVC_NAME>~$MLWB_NIFI_REGISTRY_PVC_NAME~g" deploy/nifi-registry-deployment.yaml
  sedi "s~<ACUMOS_LOGS_PVC_NAME>~$ACUMOS_LOGS_PVC_NAME~g" deploy/nifi-registry-deployment.yaml
  sedi "s~<MLWB_NIFI_REGISTRY_SERVICE_LABEL>~$MLWB_NIFI_REGISTRY_SERVICE_LABEL~g" deploy/nifi-registry-deployment.yaml
  replace_env deploy/ingress-registry.yaml
  replace_env deploy/namespace-admin-role.yaml
  replace_env deploy/namespace-admin-rolebinding.yaml
  replace_env deploy/nifi-registry-service.yaml

  log "Create templates configmap for nifi"
  cp -r templates deploy/.
  replace_env deploy/templates/deployment.yaml
  replace_env deploy/templates/service.yaml
  replace_env deploy/templates/service_admin.yaml
  replace_env deploy/templates/ingress.yaml
  # Have to use sed since some files contain '<>' sequences that break replace_env
  sedi "s/<ACUMOS_DOMAIN>/$ACUMOS_DOMAIN/g" deploy/templates/apache_configmap.yaml
  sedi "s/<ACUMOS_PORT>/$ACUMOS_PORT/g" deploy/templates/apache_configmap.yaml
  sedi "s/<ACUMOS_NAMESPACE>/$ACUMOS_NAMESPACE/g" deploy/templates/apache_configmap.yaml
  sedi "s/<ACUMOS_DOMAIN>/$ACUMOS_DOMAIN/g" deploy/templates/nifi_configmap.yaml
  sedi "s/<ACUMOS_NAMESPACE>/$ACUMOS_NAMESPACE/g" deploy/templates/nifi_configmap.yaml
  sedi "s/<KEYSTORE_PASSWORD>/$MLWB_NIFI_KEYSTORE_PASSWORD/g" deploy/templates/nifi_configmap.yaml
  sedi "s/<CERT_KEY_PASSWORD>/$MLWB_NIFI_KEY_PASSWORD/g" deploy/templates/nifi_configmap.yaml
  sedi "s/<TRUSTSTORE_PASSWORD>/$MLWB_NIFI_TRUSTSTORE_PASSWORD/g" deploy/templates/nifi_configmap.yaml
  kubectl create configmap nifi-templates -n $ACUMOS_NAMESPACE \
    --from-file=deploy/templates

  log "Create configmap nifi-registry-apache"
  kubectl create -f deploy/nifi-registry-apache-configmap.yaml

  log "Create NiFi Registry PVC in namespace $ACUMOS_NAMESPACE"
  setup_pvc $ACUMOS_NAMESPACE $MLWB_NIFI_REGISTRY_PVC_NAME \
    $MLWB_NIFI_REGISTRY_PV_NAME $MLWB_NIFI_REGISTRY_PV_SIZE

  if [[ "$ACUMOS_DEPLOY_INGRESS" == "true" ]]; then
    log "Create NiFi Registry ingress"
    kubectl create -f deploy/ingress-registry.yaml
  fi

  log "Create NiFi Registry service and deployment"
  kubectl create -f deploy/nifi-registry-service.yaml
  kubectl create -f deploy/nifi-registry-deployment.yaml
  wait_running nifi-registry $ACUMOS_NAMESPACE

  log "Enable Pipeline Service to create NiFi user services under k8s"
  kubectl create -f deploy/namespace-admin-role.yaml
  kubectl create -f deploy/namespace-admin-rolebinding.yaml

  log "Create initial NiFi admin user"
  MLWB_NIFI_REGISTRY_INITIAL_ADMIN_PASSWORD=$(uuidgen)
  sedi "s/MLWB_NIFI_REGISTRY_INITIAL_ADMIN_PASSWORD=.*/MLWB_NIFI_REGISTRY_INITIAL_ADMIN_PASSWORD=$MLWB_NIFI_REGISTRY_INITIAL_ADMIN_PASSWORD/" ../mlwb_env.sh
  bash $AIO_ROOT/../tests/create_user.sh $AIO_ROOT/acumos_env.sh $MLWB_NIFI_REGISTRY_INITIAL_ADMIN \
    $MLWB_NIFI_REGISTRY_INITIAL_ADMIN_PASSWORD \
    $(echo $MLWB_NIFI_REGISTRY_INITIAL_ADMIN_NAME | cut -d ' ' -f 1) \
    $(echo $MLWB_NIFI_REGISTRY_INITIAL_ADMIN_NAME | cut -d ' ' -f 2) \
    $MLWB_NIFI_REGISTRY_INITIAL_ADMIN_EMAIL Admin
}

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ../../AIO; pwd -P)"; fi
source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh
action=$1
if [[ "$action" == "" ]]; then action=all; fi
if [[ "$action" == "clean" || "$action" == "all" ]]; then clean_nifi; fi
if [[ "$action" == "setup" || "$action" == "all" ]]; then setup_nifi; fi
cd $WORK_DIR
