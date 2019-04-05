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
# $ bash setup-nifi.sh <namespace>
#   namespace: namespace to deploy under
#
# Useful commands
# kubectl describe pods -n $namespace nifi-0
# kubectl get svc -n $namespace
# kubectl logs -f -n $namespace nifi-0 server
# kubectl logs -f -n $namespace nifi-0 bootstrap-log

function clean() {
  helm delete --purge nifi

  while [[ "$(helm list nifi)" != "" ]]; do
    log "Wait 10 seconds for nifi helm release to be purged"
    sleep 10
  done

  log "Deleting PVCs for nifi helm release (not automatically deleted)"
  kubectl delete pvc -n $namespace content-repository-nifi-0
  kubectl delete pvc -n $namespace data-nifi-0
  kubectl delete pvc -n $namespace flowfile-repository-nifi-0
  kubectl delete pvc -n $namespace logs-nifi-0
  kubectl delete pvc -n $namespace provenance-repository-nifi-0
}

namespace=$1

#helm install --namespace $namespace --name zookeeper incubator/zookeeper

git clone https://github.com/hsz-devops/helm--apache-nifi.git
cd helm--apache-nifi
# comment out zoopkeeper config in requirements.yaml
# values.yaml
  # replicaCount: 1
  # loadBalancer:
    # enabled: false
  # sts:
    # hostPort: 443
  # service:
    # type: NodePort
  # zookeeper
    # enabled: false
    # url: "zookeeper-0.zookeeper-headless"
  # ingress:
    # enabled: false
  # properties:
    # httpPort: 8080
    # httpsPort: null
    # clusterSecure: false
    # needClientAuth: false
# templates/service-headless.yaml
  # remove "clusterIP: None"

# templates/ingress.yaml:
  # tls:
    # secret:
      # - secretName: {{ .Values.ingress.tlsSecretName |default (print "tls-le--" (include "apache-nifi.fullname" .)) }}

helm upgrade --install nifi --namespace $namespace -f values-$namespace.yaml .
kubectl get pvc -n $namespace | grep nifi
