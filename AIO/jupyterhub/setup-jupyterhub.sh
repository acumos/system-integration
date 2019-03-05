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
# NOTE: experimental use only; does not yet include Acumos user authentication.
#
# Prerequisites:
# - kubernetes cluster installed
# - PVs setup for jupyterhub data, e.g. via the setup-pv.sh script from the
#   Acumos training repo
# - helm installed under the k8s cluster
# - kubectl and helm installed on the user's workstation
# - user workstation setup to use a k8s profile for the target k8s cluster
#   e.g. using the Acumos kubernetes-client repo tools
#   $ bash kubernetes-client/deploy/private/setup-kubectl.sh k8smaster ubuntu acumos
#
# Usage: on the user's workstation
# $ bash setup-jupytyerhub.sh <namespace> <token_mode> <onboarding_port>
#   namespace: namespace to deploy under
#   token_mode: value of ACUMOS_ONBOARDING_TOKENMODE for the Acumos platform
#   onboarding_port: value of ACUMOS_ONBOARDING_PORT for the Acumos platform
#
# To release a failed PV:
# kubectl patch pv/pv-5 --type json -p '[{ "op": "remove", "path": "/spec/claimRef" }]'

function fail() {
  log "$1"
  exit 1
}

function log() {
  set +x
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  echo; echo "$fname:$fline ($(date)) $1"
  set -x
}

function prereqs() {
 log "Setup prerequisites"
 # Per https://z2jh.jupyter.org/en/latest/setup-jupyterhub.html
 if [[ ! $(which helm) ]]; then
   # Install a helm client per https://github.com/helm/helm/releases"
   wget https://storage.googleapis.com/kubernetes-helm/helm-v2.12.3-linux-amd64.tar.gz
   gzip -d helm-v2.12.3-linux-amd64.tar.gz
   tar -xvf helm-v2.12.3-linux-amd64.tar
   sudo cp linux-amd64/helm /usr/local/sbin/.
 fi

 log "Initialize helm"
 helm init
}

function setup() {
  log "Setup jupyterhub"
  log "Add jupyterhub repo to helm"
  helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
  helm repo update

  log "Customize jupyterhub config.yaml with secretToken, turn off user \
persistent storage, add selectable notebook environments"
  # Get the latest image tag at:
  # https://hub.docker.com/r/jupyter/<nbtype>-notebook/tags/
  tag=latest
  secret=$(openssl rand -hex 32)
  # https://zero-to-jupyterhub.readthedocs.io/en/latest/user-storage.html
  # https://zero-to-jupyterhub.readthedocs.io/en/stable/user-environment.html
  cat <<EOF >config.yaml
proxy:
  secretToken: "$secret"
hub:
  extraConfig: |
    c.Spawner.cmd = ['jupyter-labhub']
#    c.KubeSpawner.profile_list = [
#        {
#            "display_name": "Minimal environment",
#            "kubespawner_override": {
#                "image": "jupyter/minimal-notebook:$tag"
#            }
#        }, {
#            "display_name": "R environment",
#            "kubespawner_override": {
#                "image": "jupyter/r-notebook:$tag"
#            }
#            "display_name": "Scipy environment",
#            "kubespawner_override": {
#                "image": "jupyter/scipy-notebook:$tag"
#            }
#        }, {
#            "display_name": "Tensorflow environment",
#            "kubespawner_override": {
#            }
#        }, {
#            "display_name": "Datascience environment",
#            "kubespawner_override": {
#                "image": "jupyter/datascience-notebook:$tag"
#            }
#        }, {
#            "display_name": "Pyspark environment",
#            "kubespawner_override": {
#                "image": "jupyter/pyspark-notebook:$tag"
#            }
#        }, {
#            "display_name": "All-spark environment",
#            "kubespawner_override": {
#                "image": "jupyter/all-spark-notebook:$tag"
#            }
#        }
#    ]
singleuser:
  extraEnv:
    ACUMOS_ONBOARDING_TOKENMODE: $ACUMOS_ONBOARDING_TOKENMODE
    ACUMOS_ONBOARDING_CLIPUSHURL: "http://onboarding-service:$ACUMOS_ONBOARDING_PORT/onboarding-app/v2/models"
    ACUMOS_ONBOARDING_CLIAUTHURL: "http://onboarding-service:$ACUMOS_ONBOARDING_PORT/onboarding-app/v2/auth"
  defaultUrl: "/lab"
  storage:
    type: none
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
  cat config.yaml

  log "Install jupyterhub"
  RELEASE=jupyterhub

  if [[ ! $(helm upgrade --install $RELEASE jupyterhub/jupyterhub --namespace $namespace --version=v0.7.0-beta.1 --values config.yaml) ]]; then
    fail "Jupyterhub install via Helm failed"
  fi

  log "Deploy is complete!"
  cluster=$(kubectl config get-contexts \
    $(kubectl config view | awk '/current-context/{print $2}') \
    | awk '/\*/{print $3}')
  server=$(kubectl config view \
    -o jsonpath="{.clusters[?(@.name == \"$cluster\")].cluster.server}" \
    | cut -d '/' -f 3 | cut -d ':' -f 1)
  nodePort=$(kubectl get svc -n $namespace -o json proxy-public | jq  '.spec.ports[0].nodePort')
  echo "Access jupyterhub at http://$server:$nodePort"
}

namespace=$1
ACUMOS_ONBOARDING_TOKENMODE=$2
ACUMOS_ONBOARDING_PORT=$3
prereqs
setup
