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
#
# Usage: on the user's workstation
# $ bash setup-jupytyerhub.sh <env>
#   env: path to acumos_env.sh, which defines at minimum
#     ACUMOS_NAMESPACE
#     ACUMOS_ONBOARDING_TOKENMODE
#     ACUMOS_CDS_USER
#     ACUMOS_CDS_PASSWORD
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

function setup() {
  if [[ "$(helm list jupyterhub)" != "" ]]; then
    log "Delete/purge current jupyterhub service"
    helm delete --purge jupyterhub
    kubectl delete ingress -n $ACUMOS_NAMESPACE jupyterhub-ingress && true
  fi
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
  tmp=/tmp/$(uuidgen)
  cat <<EOF >$tmp
proxy:
  secretToken: "$secret"
  type: ClusterIP
hub:
  extraConfig: |
    from traitlets import Unicode
    from jupyterhub.auth import Authenticator
    import json
    import requests
    import os, sys
    from tornado import gen
    class AcumosAuthenticator(Authenticator):
      @gen.coroutine
      def authenticate(self, handler, data):
        cds_url = "http://cds-service:8000/ccds/user/login"
        cds_user = "$ACUMOS_CDS_USER"
        cds_password = "$ACUMOS_CDS_PASSWORD"
        username = data['username']
        data = {"name" : username, "pass" : data['password']}
        data_json = json.dumps(data)
        headers = {'Content-type': 'application/json'}
        response = requests.post(cds_url, data=data_json, headers=headers,auth=(cds_user, cds_password))
        json_data = json.loads(response.text)
        if json_data.get('authToken')   :
          return username
        else:
          return None
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
  cat $tmp

  log "Install jupyterhub"
  RELEASE=jupyterhub

  if [[ ! $(helm upgrade --install $RELEASE jupyterhub/jupyterhub --namespace $ACUMOS_NAMESPACE --version=v0.7.0-beta.1 --values $tmp) ]]; then
    fail "Jupyterhub install via Helm failed"
  fi
  rm $tmp

  log "Setup ingress for Jupyterhub"
  cat <<EOF >jupyterhub-ingress.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  namespace: $ACUMOS_NAMESPACE
  name: jupyterhub-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  tls:
  - hosts:
    - $ACUMOS_DOMAIN
    secretName: ingress-cert
  rules:
  - host: $ACUMOS_DOMAIN
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

  log "Deploy is complete!"
  echo "Access jupyterhub at https://$ACUMOS_DOMAIN/hub/"
}

source $1
setup
