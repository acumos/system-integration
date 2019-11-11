#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2018-2019 AT&T Intellectual Property. All rights reserved.
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
# What this is: script to setup JupyterHub as a service of the Acumos platform
#
# Prerequisites:
# - kubernetes cluster installed
# - PVs setup for jupyterhub data, e.g. via the setup_pv.sh script from the
#   Acumos training repo
# - helm installed under the k8s cluster, e.g. via
#   wget https://storage.googleapis.com/kubernetes-helm/helm-v2.12.3-linux-amd64.tar.gz
#   gzip -d helm-v2.12.3-linux-amd64.tar.gz
#   tar -xvf helm-v2.12.3-linux-amd64.tar
#   sudo cp linux-amd64/helm /usr/local/sbin/.
#   helm init
# - kubectl and helm installed on the user's workstation
# - user workstation setup to use a k8s profile for the target k8s cluster
#   e.g. using the Acumos kubernetes-client repo tools
#   $ bash kubernetes-client/deploy/private/setup_kubectl.sh k8smaster ubuntu acumos
# - Key-based SSH access to the Acumos host, for updating docker images
#
# Usage: on the installing user's workstation or on the target host
# $ bash setup_jupyterhub.sh <setup|clean|all> <NAMESPACE> <ACUMOS_ORIGIN>
#   <ACUMOS_ONBOARDING_TOKENMODE> [standalone] [CERT] [CERT_KEY]#
#   setup|clean|all: action to take
#   additional parameters for action 'setup' or 'all':
#     NAMESPACE: namespace under which to deploy JupyterHub
#
#   additional parameters for action setup|all:
#     ACUMOS_ORIGIN: domain name (and port, if not 443) of the Acumos platform
#       (ingress controller)
#     ACUMOS_ONBOARDING_TOKENMODE: tokenmode set in the Acumos platform
#     standalone: (optional) setup a standalone JupyterHub instance
#
#     (optional) For standalone deployment, add these parameters to use pre-created
#     certificates for the jupyterhub ingress controller, and place the files in
#     system-integration/charts/jupyterhub/certs
#     CERT: filename of certificate
#     CERT_KEY: filename of certificate key
#
#     Setting up a standalone JupyterHub requires a dedicated host, on which:
#       - a single-node Kubernetes cluster will be created
#       - an NGINX ingress controller will be created, using self-signed certs or
#         certs as specified, and set to serve requests at "MLWB_JUPYTERHUB_DOMAIN"
#       - set the mlwb_env.sh values for the following, per the target host
#         export MLWB_JUPYTERHUB_DOMAIN=<FQDN or hostname>
#         export MLWB_JUPYTERHUB_HOST=<hostname>
#
# To release a failed PV:
# kubectl patch pv/pv-5 --type json -p '[{ "op": "remove", "path": "/spec/claimRef" }]'

function standalone_prep() {
  trap 'fail' ERR
  if [[ $(helm delete --purge $NAMESPACE-jupyterhub) ]]; then
    log "Helm release $NAMESPACE-jupyterhub deleted"
  fi

  if [[ "$ACUMOS_DEPLOY_INGRESS_RULES" == "true" ]]; then
    ings=$(kubectl get ingress -n $NAMESPACE | awk '/-ingress/{print $1}')
    for ing in $ings; do
      if [[ $(kubectl delete ingress -n $NAMESPACE $ing) ]]; then
        log "Ingress $ing deleted"
      fi
    done
  fi

  log "Delete pods and PVCs for Jupyter SingleUser containers (not cleaned up by Helm)"
  if [[ $(kubectl get pod -n $NAMESPACE -o json | jq ".items | length") -gt 0 ]]; then
    pods=$(kubectl get pod -n $NAMESPACE | awk '/jupyter/{print $1}')
    for pod in $pods; do
      kubectl delete pod -n $NAMESPACE $pod
    done
  fi
  if [[ $(kubectl get pvc -n $NAMESPACE -o json | jq ".items | length") -gt 0 ]]; then
    pvcs=$(kubectl get pvc -n $NAMESPACE | awk '/claim/{print $1}')
    for pvc in $pvcs; do
      # Avoid hangs due to https://kubernetes.io/docs/concepts/storage/persistent-volumes/#storage-object-in-use-protection
      kubectl patch pvc -n $NAMESPACE $pvc -p '{"metadata":{"finalizers": []}}' --type=merge
      kubectl delete pvc -n $NAMESPACE $pvc
    done
  fi

  log "Create PV for JupyterHub"
  bash $AIO_ROOT/../tools/setup_pv.sh all /mnt/$NAMESPACE \
     $MLWB_JUPYTERHUB_HUB_PV_NAME 1Gi $USER:$USER

  cd certs
  if [[ "$CERT" == "" ]]; then
    rm *
    bash $AIO_ROOT/certs/setup_certs.sh jupyterhub $MLWB_JUPYTERHUB_DOMAIN
    source cert_env.sh
    CERT=$(pwd)/jupyterhub.crt
    CERT_KEY=$(pwd)/jupyterhub.key
  else
    CERT=$(pwd)/$CERT
    CERT_KEY=$(pwd)/$CERT_KEY
  fi
  cd ..
}

function clean() {
  trap 'fail' ERR
  if [[ $(helm delete --purge $NAMESPACE-jupyterhub) ]]; then
    log "Helm release $NAMESPACE-jupyterhub deleted"
  fi
  if [[ "$ACUMOS_DEPLOY_INGRESS_RULES" == "true" ]]; then
    if [[ $(kubectl delete ingress -n $NAMESPACE jupyterhub-ingress) ]]; then
      log "Ingress jupyterhub-ingress deleted"
    fi
  fi
}

function setup() {
  trap 'fail' ERR

  log "Setup jupyterhub"

  log "Add jupyterhub repo to helm"
  helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
  helm repo update

  log "Generate API token"
  token=$(openssl rand -hex 32)
  update_mlwb_env MLWB_JUPYTERHUB_API_TOKEN $token force

  log "Customize jupyterhub config.yaml"
  # Get the latest image tag at:
  # https://hub.docker.com/r/jupyter/<nbtype>-notebook/tags/
  # Using the last build with python 3.6, since the Acumos library requires <3.7
  # MLWB_JUPYTERHUB_IMAGE_TAG=9e8682c9ea54
  tag=$MLWB_JUPYTERHUB_IMAGE_TAG
  # https://zero-to-jupyterhub.readthedocs.io/en/latest/user-storage.html
  # https://zero-to-jupyterhub.readthedocs.io/en/stable/user-environment.html
  tmp=/tmp/$(uuidgen)
  cat <<EOF >$tmp
proxy:
  secretToken: "$MLWB_JUPYTERHUB_API_TOKEN"
  type: ClusterIP
hub:
  extraConfig:
    acumos: |
      from traitlets import Unicode
      from jupyterhub.auth import Authenticator
      import json
      import requests
      import os, sys
      from tornado import gen
      class AcumosAuthenticator(Authenticator):
        @gen.coroutine
        def authenticate(self, handler, data):
          if "$MLWB_JUPYTERHUB_DOMAIN" == "$ACUMOS_DOMAIN" :
            auth_url = "http://onboarding-service:8090/onboarding-app/v2/auth"
          else:
            auth_url = "https://$ACUMOS_ORIGIN/onboarding-app/v2/auth"
          username = data['username']
          data = { "request_body": {"username": username, "password": data['password']}}
          data_json = json.dumps(data)
          headers = {'Content-type': 'application/json'}
          response = requests.post(auth_url, data=data_json, headers=headers, verify=False)
          if response.status_code == 200 :
            return username
          else:
            return None
      c.Authenticator.admin_users = {'admin'}
      c.JupyterHub.admin_access = True
      c.JupyterHub.api_tokens = { "$MLWB_JUPYTERHUB_API_TOKEN": 'admin' }
      c.JupyterHub.trust_user_provided_tokens = True
      c.JupyterHub.authenticator_class = AcumosAuthenticator
      c.Spawner.cmd = ['jupyter-labhub']
      c.KubeSpawner.profile_list = [
        { "display_name": "Minimal environment",
          "kubespawner_override": {
            "image": "jupyter/minimal-notebook:$tag"
          }
        },
        { "display_name": "R environment",
          "kubespawner_override": {
            "image": "jupyter/r-notebook:$tag"
          }
        },
        { "display_name": "Scipy environment",
          "kubespawner_override": {
            "image": "jupyter/scipy-notebook:$tag"
          }
        },
        { "display_name": "Tensorflow environment",
          "kubespawner_override": {}
        },
        { "display_name": "Datascience environment",
          "kubespawner_override": {
            "image": "jupyter/datascience-notebook:$tag"
          }
        },
        { "display_name": "Pyspark environment",
          "kubespawner_override": {
            "image": "jupyter/pyspark-notebook:$tag"
          }
        },
        { "display_name": "All-spark environment",
          "kubespawner_override": {
            "image": "jupyter/all-spark-notebook:$tag"
          }
        }
      ]
singleuser:
  extraEnv:
    ACUMOS_ONBOARDING_TOKENMODE: $ACUMOS_ONBOARDING_TOKENMODE
    ACUMOS_ONBOARDING_CLIPUSHURL: "http://onboarding-service:8090/onboarding-app/v2/models"
    ACUMOS_ONBOARDING_CLIAUTHURL: "http://onboarding-service:8090/onboarding-app/v2/auth"
  defaultUrl: "/lab"
  image:
    name: jupyter/tensorflow-notebook
    tag: $tag
  profileList:
    - display_name: "Minimal environment"
      description: "To avoid too many bells and whistles: Python."
      kubespawner_override:
        name: jupyter/minimal-notebook:$tag
    - display_name: "R environment"
      description: "Includes popular packages from the R ecosystem"
      kubespawner_override:
        image: jupyter/r-notebook:$tag
    - display_name: "Scipy environment"
      description: "Includes popular packages from the scientific Python ecosystem"
      kubespawner_override:
        image: jupyter/scipy-notebook:$tag
    - display_name: "Tensorflow environment"
      description: "Includes popular Python deep learning libraries"
      default: true
      kubespawner_override:
        image: jupyter/tensorflow-notebook:$tag
    - display_name: "Datascience environment"
      description: "Includes libraries for data analysis from the Julia, Python, and R communities."
      kubespawner_override:
        image: jupyter/datascience-notebook:$tag
    - display_name: "Pyspark environment"
      description: "Includes Python support for Apache Spark, optionally on Mesos"
      kubespawner_override:
        image: jupyter/pyspark-notebook:$tag
    - display_name: "All-spark environment"
      description: "Includes Python, R, and Scala support for Apache Spark, optionally on Mesos"
      kubespawner_override:
        image: jupyter/all-spark-notebook:$tag
EOF
  cat $tmp

  log "Install jupyterhub"
  RELEASE=${NAMESPACE}-jupyterhub

  log "Attempting to deploy Jupyterhub via Helm"
  helm repo update
  helm fetch jupyterhub/jupyterhub
  helm install --name $RELEASE jupyterhub/jupyterhub \
    --timeout $ACUMOS_SUCCESS_WAIT_TIME \
    --namespace $NAMESPACE \
    --version=v0.8.2 --values $tmp
  rm $tmp

  local t=0
  while [[ "$(helm list $RELEASE --output json | jq -r '.Releases[0].Status')" != "Deployed" ]]; do
    if [[ $t -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      fail "$RELEASE is not ready after $ACUMOS_SUCCESS_WAIT_TIME seconds"
    fi
    log "$RELEASE Helm release is not yet Deployed, waiting 10 seconds"
    sleep 10
    t=$((t+10))
  done

  if [[ "$ACUMOS_DEPLOY_INGRESS" == "true" && "$STANDALONE" == "standalone" && "$ACUMOS_K8S_ADMIN_SCOPE" == "cluster" ]]; then
    HOST_IP=$(/sbin/ip route get 8.8.8.8 | head -1 | sed 's/^.*src //' | awk '{print $1}')
    bash ../ingress/setup_ingress_controller.sh $NAMESPACE $HOST_IP $CERT $CERT_KEY
  fi

  if [[ "$ACUMOS_DEPLOY_INGRESS_RULES" == "true" ]]; then
    log "Setup ingress for Jupyterhub"
    cat <<EOF >jupyterhub-ingress.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  namespace: $NAMESPACE
  name: jupyterhub-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  tls:
  - hosts:
    - $MLWB_JUPYTERHUB_DOMAIN
    secretName: ingress-cert
  rules:
  - host: $MLWB_JUPYTERHUB_DOMAIN
    http:
      paths:
      - path: "/hub/"
        backend:
          serviceName: hub
          servicePort: 8081
      - path: "/user/"
        backend:
          serviceName: proxy-public
          servicePort: 80
EOF

    if [[ ! $(kubectl create -f jupyterhub-ingress.yaml) ]]; then
      fail "Setup ingress for Jupyterhub failed"
    fi
  fi

  log "Patch deployment to resolve Acumos domain in case not registered in DNS"
  bash $AIO_ROOT/../tools/add_host_alias.sh k8s $ACUMOS_DOMAIN jupyterhub $NAMESPACE hub

  log "Deploy is complete!"
  echo "Access jupyterhub at https://$MLWB_JUPYTERHUB_DOMAIN/hub/"
}

if [[ $# -lt 2 ]]; then usage=yes;
elif [[ "$1" != 'clean' && $# -lt 4 ]]; then usage=yes
fi

if [[ "$usage" == "yes" ]]; then
  cat <<'EOF'
Usage: on the installing user's workstation or on the target host
$ bash setup_jupyterhub.sh <setup|clean|all> <NAMESPACE> <ACUMOS_ORIGIN>
   <ACUMOS_ONBOARDING_TOKENMODE> [standalone] [CERT] [CERT_KEY]#
   setup|clean|all: action to take
   NAMESPACE: namespace under which to deploy JupyterHub

   additional parameters for action setup|all:
   ACUMOS_ORIGIN: domain name (and port, if not 443) of the Acumos platform
     (ingress controller)
   ACUMOS_ONBOARDING_TOKENMODE: tokenmode set in the Acumos platform
   standalone: (optional) setup a standalone JupyterHub instance

   (optional) For standalone deployment, add these parameters to use pre-created
   certificates for the jupyterhub ingress controller, and place the files in
   system-integration/charts/jupyterhub/certs
   CERT: filename of certificate
   CERT_KEY: filename of certificate key

   Setting up a standalone JupyterHub requires:
     - a pre-existing k8s cluster in which
     - an NGINX ingress controller (to be created if needed) , using self-signed
       certs or certs as specified, and set to serve requests at "MLWB_JUPYTERHUB_DOMAIN"
     - set the mlwb_env.sh values for the following, per the target host
       export MLWB_JUPYTERHUB_DOMAIN=<FQDN or hostname>
       export MLWB_JUPYTERHUB_HOST=<hostname>
       export MLWB_JUPYTERHUB_HOST_IP=<IP address of primary interface>
EOF
  log "All parameters not provided"
  exit 1
fi

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ../../AIO; pwd -P)"; fi
source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh
# Set this again in case it was not set in acumos_env.sh
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ../../AIO; pwd -P)"; fi
source $AIO_ROOT/mlwb/mlwb_env.sh

action=$1
NAMESPACE=$2
update_mlwb_env MLWB_JUPYTERHUB_NAMESPACE $NAMESPACE force
export DEPLOYED_UNDER=k8s
export K8S_DIST=generic
if [[ "$action" == "clean" || "$action" == "all" ]]; then clean; fi
if [[ "$action" == "setup" || "$action" == "all" ]]; then
  ACUMOS_ORIGIN=$3
  ACUMOS_DOMAIN=$(echo $ACUMOS_ORIGIN | cut -d ":" -f 1)
  ACUMOS_ONBOARDING_TOKENMODE=$4
  STANDALONE=$5
  if [[ "$STANDALONE" == "standalone" ]]; then
    CERT=$5
    CERT_KEY=$6
    standalone_prep
  fi
  setup
fi
cd $WORK_DIR
