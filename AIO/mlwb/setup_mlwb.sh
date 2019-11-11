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
#   in mlwb_env.sh, and copy the JupyterHub server cert to
#   system-integration/charts/jupyterhub/certs
#     export MLWB_DEPLOY_JUPYTERHUB=false
#     export MLWB_JUPYTERHUB_DOMAIN=<FQDN of JupyterHub>
#     export MLWB_JUPYTERHUB_HOST=<hostname of JupyterHub>
#     export MLWB_JUPYTERHUB_HOST_IP=<IP address of JupyterHub>
#     export MLWB_JUPYTERHUB_CERT=<JupyterHub cert filename>
#     export MLWB_JUPYTERHUB_API_TOKEN=<JupyterHub API token>
#
# - Key-based SSH access to the Acumos host, for updating docker images
#
# Usage:
# $ bash setup_mlwb.sh [setup|clean|all]
#  setup: setup the MLWB components
#  clean: stop the MLWB components
#  all: (default) stop and setup
#

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
    log "Delete all MLWB resources"
    clean_resource $ACUMOS_NAMESPACE deployment mlwb
    clean_resource $ACUMOS_NAMESPACE pods mlwb
    clean_resource $ACUMOS_NAMESPACE service mlwb
    clean_resource $ACUMOS_NAMESPACE configmap mlwb
    clean_resource $ACUMOS_NAMESPACE secret mlwb
    clean_resource $ACUMOS_NAMESPACE pvc mlwb
    if [[ "$ACUMOS_DEPLOY_INGRESS_RULES" == "true" ]]; then
      clean_resource $ACUMOS_NAMESPACE ingress mlwb
    fi
  fi
  cleanup_snapshot_images
}

function setup_jupyterhub_certs_configmap() {
  trap 'fail' ERR

  # See prerequisites above if deploying with a standalone JupyterHub service
  if [[ ! -e $AIO_ROOT/../charts/jupyterhub/certs/$MLWB_JUPYTERHUB_CERT ]]; then
    log "Copy Acumos server cert for use as JupyterHub cert"
    mkdir -p $AIO_ROOT/../charts/jupyterhub/certs/
    cp $AIO_ROOT/certs/$ACUMOS_CERT $AIO_ROOT/../charts/jupyterhub/certs/.
    update_mlwb_env MLWB_JUPYTERHUB_CERT $ACUMOS_CERT
  fi

  log "Create secret mlwb-jupyterhub-certs"
  kubectl create secret generic -n $ACUMOS_NAMESPACE mlwb-jupyterhub-certs \
    -o yaml --from-file=$AIO_ROOT/../charts/jupyterhub/certs/$MLWB_JUPYTERHUB_CERT
}

setup_mlwb() {
  trap 'fail' ERR

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Setup PV for JupyterHub certs"

    log "Deploy MLWB docker-based components"
    bash docker_compose.sh up -d --build
  else
    setup_jupyterhub_certs_configmap
    log "Apply updates to mlwb_env.sh"
    source mlwb_env.sh

    if [[ ! -e deploy ]]; then mkdir deploy; fi

    apps="mlwb-dashboard-webcomponent mlwb-home-webcomponent \
mlwb-project mlwb-project-webcomponent mlwb-project-catalog-webcomponent \
mlwb-notebook mlwb-notebook-webcomponent mlwb-notebook-catalog-webcomponent \
mlwb-model mlwb-predictor"

    cp kubernetes/mlwb-dashboard* deploy/.
    cp kubernetes/mlwb-home* deploy/.
    cp kubernetes/mlwb-model* deploy/.
    cp kubernetes/mlwb-notebook* deploy/.
    cp kubernetes/mlwb-project* deploy/.
    cp kubernetes/mlwb-predictor* deploy/.

    if [[ "$MLWB_DEPLOY_PIPELINE" == "true" ]]; then
      apps="$apps mlwb-pipeline mlwb-pipeline-webcomponent mlwb-pipeline-catalog-webcomponent"
      cp kubernetes/mlwb-pipeline* deploy/.
      if [[ "$MLWB_NIFI_EXTERNAL_PIPELINE_SERVICE" == "true" ]]; then
        log "Remove pipeline service template dependencies on NiFi"
        sedi '/\/maven\/conf/,/nifi-templates/d' deploy/mlwb-pipeline-service-deployment.yaml
        sedi '/- name: nifi-certs-registry/,/secretName: nifi-certs-registry/d' deploy/mlwb-pipeline-service-deployment.yaml
        sedi '/- name: nifi-templates/,/name: nifi-templates/d' deploy/mlwb-pipeline-service-deployment.yaml
        sedi '/command: /,/java/d' deploy/mlwb-pipeline-service-deployment.yaml
      fi
    fi

    log "Set variable values in k8s templates"
    replace_env deploy

    log "Deploy the MLWB k8s-based components"
    # Create services first... see https://github.com/kubernetes/kubernetes/issues/16448
    if [[ "$ACUMOS_DEPLOY_INGRESS_RULES" == "true" ]]; then
      for f in  deploy/*-ingress.yaml ; do
        log "Creating ingress from $f"
        kubectl create -f $f
      done
    fi
    for f in  deploy/*-service.yaml ; do
      log "Creating service from $f"
      kubectl create -f $f
    done
    for f in  deploy/*-deployment.yaml ; do
      log "Creating deployment from $f"
      kubectl create -f $f
    done
    get_host_ip_from_etc_hosts $MLWB_JUPYTERHUB_DOMAIN
    if [[ "$HOST_IP" != "" ]]; then
      patch_deployment_with_host_alias $ACUMOS_NAMESPACE mlwb-notebook \
       $MLWB_JUPYTERHUB_DOMAIN $HOST_IP
    fi

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
# Hard-set these values in case JupyterHub setup is run later
update_mlwb_env MLWB_JUPYTERHUB_DOMAIN $MLWB_JUPYTERHUB_DOMAIN force
update_mlwb_env MLWB_JUPYTERHUB_HOST $MLWB_JUPYTERHUB_HOST force
update_mlwb_env MLWB_JUPYTERHUB_HOST_IP $MLWB_JUPYTERHUB_HOST_IP force

action=$1
if [[ "$action" == "" ]]; then action=all; fi

if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
  update_mlwb_env MLWB_DEPLOY_JUPYTERHUB false
  update_mlwb_env MLWB_DEPLOY_NIFI false
else
  if [[ "$MLWB_DEPLOY_JUPYTERHUB" == "true" ]]; then
    bash $AIO_ROOT/../charts/jupyterhub/setup_jupyterhub.sh $action \
      $ACUMOS_NAMESPACE $ACUMOS_ORIGIN $ACUMOS_ONBOARDING_TOKENMODE
  fi
  if [[ "$MLWB_DEPLOY_NIFI" == "true" ]]; then
    bash nifi/setup_nifi.sh $action
  fi
fi
log "Apply any updates to mlwb_env.sh"
source mlwb_env.sh
if [[ "$action" == "clean" || "$action" == "all" ]]; then clean_mlwb; fi
if [[ "$action" == "setup" || "$action" == "all" ]]; then setup_mlwb; fi
cd $WORK_DIR
