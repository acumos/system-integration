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
# What this is: Deployment script for Acumos MLWB components
#
# Prerequisites:
# - Acumos deployed under docker or k8s via the AIO toolset
# - To use an external JupyterHub deployment, set the JupyterHub-related values
#   in mlwb_env.sh, and copy the keystore for the JupyterHub service to
#   system-integration/charts/jupyterhub/certs
#     export MLWB_DEPLOY_JUPYTERHUB=false
#     export MLWB_JUPYTERHUB_DOMAIN=<domain>
#     export MLWB_JUPYTERHUB_CERT=<cert filename (.pem)>
#     export MLWB_JUPYTERHUB_CERT_KEY=<cert key filename (.pem)>
#     export MLWB_JUPYTERHUB_CERT_KEY_PASSWORD=<cert key password>
#     export MLWB_JUPYTERHUB_KEYSTORE=<PKCS12-formatted keystore file name (.p12)>
#     export MLWB_JUPYTERHUB_KEYSTORE_PASSWORD=<keystore password>
# - Key-based SSH access to the Acumos host, for updating docker images
#
# Usage:
# $ bash setup_mlwb.sh
#

clean_resource() {
  # No trap fail here, as timing issues may cause commands to fail
#  trap 'fail' ERR
  if [[ $(kubectl get $1 -n $ACUMOS_NAMESPACE -o json | jq ".items | length") -gt 0 ]]; then
    rss=$(kubectl get $1 -n $ACUMOS_NAMESPACE | awk '/mlwb/{print $1}')
    for rs in $rss; do
      kubectl delete $1 -n $ACUMOS_NAMESPACE $rs
      while [[ $(kubectl get $1 -n $ACUMOS_NAMESPACE $rs) ]]; do
        sleep 5
      done
    done
  fi
}

function clean_mlwb() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any existing docker based components for mlwb"
    cs=$(docker ps -a | awk '/mlwb/{print $1}')
    for c in $cs; do
      docker stop $c
      docker rm $c
    done
  else
    log "Stop any existing k8s based components for NiFi"
    trap - ERR
    rm -rf deploy
    log "Delete all MLWB resources"
    clean_resource deployment
    clean_resource pods
    clean_resource service
    clean_resource configmap
    clean_resource ingress
    clean_resource secret
  fi

  log "Cleanup docker images in case we need to redownload an image"
  if [[ "$HOSTNAME" == "$ACUMOS_HOST" ]]; then
    docker image prune -a -f
  else
    ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
      $ACUMOS_HOST_USER@$ACUMOS_DOMAIN docker image prune -a -f
  fi
}

function setup_jupyterhub_certs_configmap() {
  # See prerequisites above if deploying with a standalone JupyterHub service
  if [[ "$MLWB_JUPYTERHUB_DOMAIN" == "$ACUMOS_DOMAIN" ]]; then
    log "Copy Acumos keystore for use as JupyterHub keystore"
    cp $AIO_ROOT/certs/$ACUMOS_KEYSTORE_P12 $AIO_ROOT/../charts/jupyterhub/certs/.
    update_mlwb_env MLWB_JUPYTERHUB_CERT $ACUMOS_CERT
    update_mlwb_env MLWB_JUPYTERHUB_CERT_KEY $ACUMOS_CERT_KEY
    update_mlwb_env MLWB_JUPYTERHUB_CERT_KEY_PASSWORD $ACUMOS_CERT_KEY_PASSWORD
    update_mlwb_env MLWB_JUPYTERHUB_KEYSTORE $ACUMOS_KEYSTORE_P12
    update_mlwb_env MLWB_JUPYTERHUB_KEYSTORE_PASSWORD $ACUMOS_KEYSTORE_PASSWORD
  fi

  log "Create configmap mlwb-jupyterhub-certs"
  kubectl create configmap -n $ACUMOS_NAMESPACE mlwb-jupyterhub-certs \
    -o yaml --from-file=$AIO_ROOT/../charts/jupyterhub/certs/$MLWB_JUPYTERHUB_KEYSTORE
}

setup_mlwb() {
  trap 'fail' ERR

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Setup PV for JupyterHub certs"

    log "Deploy MLWB docker-based components"
    bash docker_compose.sh up -d --build
  else
    setup_jupyterhub_certs_configmap

    if [[ ! -e deploy ]]; then mkdir deploy; fi
    rm -f deploy/*

    apps="mlwb-dashboard-webcomponent mlwb-home-webcomponent \
mlwb-project mlwb-project-webcomponent mlwb-project-catalog-webcomponent \
mlwb-notebook mlwb-notebook-webcomponent mlwb-notebook-catalog-webcomponent \
mlwb-pipeline mlwb-pipeline-webcomponent mlwb-pipeline-catalog-webcomponent"

    cp kubernetes/mlwb-dashboard* deploy/.
    cp kubernetes/mlwb-home* deploy/.
    cp kubernetes/mlwb-notebook* deploy/.
    cp kubernetes/mlwb-project* deploy/.

    if [[ "$MLWB_DEPLOY_NIFI" == "true" ]]; then
      apps="$apps mlwb-pipeline mlwb-pipeline-webcomponent mlwb-pipeline-catalog-webcomponent"
      cp kubernetes/mlwb-pipeline* deploy/.
    fi

    log "Set variable values in k8s templates"
    replace_env deploy

    log "Deploy the MLWB k8s-based components"
    # Create services first... see https://github.com/kubernetes/kubernetes/issues/16448
    for f in  deploy/*-ingress.yaml ; do
      log "Creating ingress from $f"
      kubectl create -f $f
    done
    for f in  deploy/*-service.yaml ; do
      log "Creating service from $f"
      kubectl create -f $f
    done
    for f in  deploy/*-deployment.yaml ; do
      log "Creating deployment from $f"
      kubectl create -f $f
    done

    log "Wait for all MLWB core pods to be Running"
    for app in $apps; do
      wait_running $app $ACUMOS_NAMESPACE
    done
  fi
}

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ..; pwd -P)"; fi
source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh
source mlwb_env.sh
if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
  update_mlwb_env MLWB_DEPLOY_JUPYTERHUB false
  update_mlwb_env MLWB_DEPLOY_NIFI false
else
  if [[ "$MLWB_DEPLOY_NIFI" == "true" ]]; then
    bash nifi/setup_nifi.sh
  fi
  if [[ "$MLWB_DEPLOY_JUPYTERHUB" == "true" ]]; then
    bash $AIO_ROOT/../charts/jupyterhub/setup_jupyterhub.sh \
      $ACUMOS_NAMESPACE $ACUMOS_DOMAIN $ACUMOS_ONBOARDING_TOKENMODE
  fi
fi
log "Apply any updates to mlwb_env.sh"
source mlwb_env.sh
clean_mlwb
setup_mlwb
cd $WORK_DIR
