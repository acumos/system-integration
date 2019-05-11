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
  if [[ ! -d deploy ]]; then
    mkdir -p deploy
    cp kubernetes/*-deployment.yaml deploy/.
    cp kubernetes/*-service.yaml deploy/.
    replace_env deploy
  fi

  trap - ERR
  for f in  deploy/*-deployment.yaml ; do
    stop_deployment $f
  done
  for f in  deploy/*-service.yaml ; do
    stop_service $f
  done
  rm -rf deploy

  log "Delete all NiFi user resources"
  deps=$(kubectl get pods -n $ACUMOS_NAMESPACE  | awk '/nifi/{print $1}')
  for dep in $deps; do
    kubectl delete deployment -n $ACUMOS_NAMESPACE $dep
  done
  svcs=$(kubectl get svc -n $ACUMOS_NAMESPACE | awk '/nifi/{print $1}')
  for svc in $svcs; do
    kubectl delete svc -n $ACUMOS_NAMESPACE $svc
  done
  cfgs=$(kubectl get configmap -n $ACUMOS_NAMESPACE | awk '/nifi/{print $1}')
  for cfg in $cfgs; do
    kubectl delete configmap -n $ACUMOS_NAMESPACE $cfg
  done
  ings=$(kubectl get ingress -n $ACUMOS_NAMESPACE | awk '/nifi/{print $1}')
  for ing in $ings; do
    kubectl delete ingress -n $ACUMOS_NAMESPACE $ing
  done

  trap 'fail' ERR

  if [[ $(helm delete --purge nginx-ingress) ]]; then
    log "Helm release nifi-ingress deleted"
  fi

  log "Delete cert, truststore, and keystore for nifi"
  if [[ -d certs ]]; then rm -rf certs; fi
  if [[ $(kubectl delete secret -n $ACUMOS_NAMESPACE nifi-ingress) ]]; then
    log "secret nifi-ingress deleted"
  fi

  if [[ $(kubectl delete secret -n $ACUMOS_NAMESPACE nifi-certs) ]]; then
    log "secret nifi-certs deleted"
  fi

  if [[ $(kubectl delete configmap -n $ACUMOS_NAMESPACE nifi-registry-apache) ]]; then
    log "configmap nifi-registry-apache deleted"
  fi

  if [[ $(kubectl delete configmap -n $ACUMOS_NAMESPACE nifi-templates) ]]; then
    log "configmap nifi-templates deleted"
  fi

  if [[ $(kubectl delete pvc -n $ACUMOS_NAMESPACE nifi-templates) ]]; then
    log "nifi-registry PVC deleted"
  fi

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
  if [[ ! -d certs ]]; then mkdir certs; fi
  cd certs
  bash $AIO_ROOT/certs/setup_certs.sh $AIO_ROOT nifi localhost '*.nifi'
  source cert_env.sh
  kubectl create secret generic nifi-certs -n $ACUMOS_NAMESPACE -o yaml \
    --from-file=nifi.crt,nifi-truststore.jks,nifi-keystore.jks,nifi-keystore.p12
  cd ..

  log "Install nginx ingress controller via Helm"
  cat <<EOF >nifi-ingress-values.yaml
controller:
  service:
    externalIPs: [$ACUMOS_HOST_IP]
EOF
  helm install --name nginx-ingress --namespace $ACUMOS_NAMESPACE \
    -f nifi-ingress-values.yaml stable/nginx-ingress

  log "Create nifi-ingress secret using cert for $ACUMOS_DOMAIN"
  get_host_info
  if [[ "$HOST_OS" == "macos" ]]; then
    b64crt=$(cat $AIO_ROOT/certs/acumos.crt | base64)
    b64key=$(cat $AIO_ROOT/certs/acumos.key | base64)
  else
    b64crt=$(cat $AIO_ROOT/certs/acumos.crt | base64 -w 0)
    b64key=$(cat $AIO_ROOT/certs/acumos.key | base64 -w 0)
  fi
  cat <<EOF >nifi-ingress-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: nifi-ingress
  namespace: $ACUMOS_NAMESPACE
data:
  tls.crt: $b64crt
  tls.key: $b64key
type: kubernetes.io/tls
EOF
  kubectl create -f nifi-ingress-secret.yaml

  log "Update templates with environment variables"
  if [[ ! -d deploy ]]; then mkdir deploy; fi
  cp kubernetes/* deploy/.
  sedi "s/<ACUMOS_NAMESPACE>/$ACUMOS_NAMESPACE/g" deploy/nifi-registry-apache-configmap.yaml
  replace_env deploy/ingress-registry.yaml
  replace_env deploy/namespace-admin-role.yaml
  replace_env deploy/namespace-admin-rolebinding.yaml
  replace_env deploy/nifi-registry-deployment.yaml
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
  kubectl create configmap nifi-templates -n $ACUMOS_NAMESPACE \
    --from-file=deploy/templates

  log "Create configmap nifi-registry-apache"
  kubectl create -f deploy/nifi-registry-apache-configmap.yaml

  log "Create NiFi Registry PVC in namespace $ACUMOS_NAMESPACE"
  setup_pvc nifi-registry $ACUMOS_NAMESPACE $MLWB_NIFI_REGISTRY_PV_SIZE

  log "Create NiFi Registry ingress"
  kubectl create -f deploy/ingress-registry.yaml

  log "Create NiFi Registry service and deployment"
  kubectl create -f deploy/nifi-registry-service.yaml
  kubectl create -f deploy/nifi-registry-deployment.yaml
  wait_running nifi-registry $ACUMOS_NAMESPACE

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
clean_nifi
setup_nifi
cd $WORK_DIR
