#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2020 AT&T Intellectual Property & Tech Mahindra.
# All rights reserved.
# ===================================================================================
# This Acumos software file is distributed by AT&T and Tech Mahindra
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
# Name: 0c-cluster.sh - z2a 0c-cluster setup script
#
# Prerequisites:
# - Ubuntu Xenial (16.04), Bionic (18.04), or Centos 7 VM
#
# - It is assumed, that the user running this script:
#		- has sudo access on the VM
#		- has successfully ran the accompanying z2a_ph1a.sh script
#   - has logged out and back in to a new session
#
# Usage:

# Determine if the end-user is actually a member of the Docker group
# We can not proceed past here without the user being in the Docker group
id -nG | grep -q docker || {
  echo "User is not a member of the docker group."
  echo "Please log out and log back in to a new session."
  exit 1
}

# Anchor Z2A_BASE
HERE=$(realpath $(dirname $0))
Z2A_BASE=$(realpath $HERE/..)
# Source the z2a utils file
source $Z2A_BASE/z2a-utils.sh
# Load user environment
load_env
# Redirect stdout/stderr to log file
redirect_to $HERE/0c-cluster-install.log
# Exit with an error on any non-zero return code
trap 'fail' ERR

log "Starting Phase 0c-cluster creation (kind, metalLB, k8s dashboard, ingress) ...."

log "Initializing official Helm stable chart repo ...."
# Initialize the official helm stable chart repo ; perform update
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo update

log "Creating kind cluster : name = $Z2A_K8S_CLUSTERNAME (this may take a few minutes .... relax!!!!)"
# Create kind cluster (named kind-acumos)
kind create cluster --name=$Z2A_K8S_CLUSTERNAME --config $HERE/kind-config.yaml -v 9

# Echo cluster-info - echo output to both log file and TTY
log "\n\n$(kubectl cluster-info --context kind-$Z2A_K8S_CLUSTERNAME)\n"

log "Install MetalLB ...."
# Install MetalLB load Balancer
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.9.3/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.9.3/manifests/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

log "Configuring MetalLB ...."
kubectl apply -f $HERE/z2a-k8s-metallb/metallb.yaml --namespace=metallb-system

log "Installing the Kubernetes Dashboard ...."
# Download and install the Kubernetes Dashboard
curl -o $HERE/z2a-k8s-dashboard/recommended.yaml https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
egrep -v '^\s*#' $HERE/z2a-k8s-dashboard/recommended.yaml > $HERE/z2a-k8s-dashboard/main.yaml
yq w -i -d'*' $HERE/z2a-k8s-dashboard/main.yaml '**.(.==443).' 9090
yq w -i -d'*' $HERE/z2a-k8s-dashboard/main.yaml '**.(.==8443).' 9090
yq w -i -d'*' $HERE/z2a-k8s-dashboard/main.yaml '**.(.==HTTPS).' HTTP
yq w -i -d'*' $HERE/z2a-k8s-dashboard/main.yaml '**.(.==--auto-generate-certificates).' -- '--enable-insecure-login'
kubectl apply -f $HERE/z2a-k8s-dashboard/main.yaml

log "Creating Kubernetes Dashboard Service Account ...."
# Create Service Account
kubectl apply -f $HERE/z2a-k8s-dashboard/admin-user.yaml

log "Creating Kubernetes Dashboard ClusterRole Binding ...."
# Create k8s Cluster Role Binding
kubectl apply -f $HERE/z2a-k8s-dashboard/clusterrolebinding.yaml

log "Installing Kubernetes native ingress controller (nginX) ...."
# Note: this k8s manifest is `kind` specific - do not install this as an ingress controller on a real k8s cluster
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml

log "Capturing Kubernetes Cluster Status ...."
# Capture k8s cluster status
kubectl get all -A

log "Capturing Default Bearer Token ...."
# Get the Default Bearer Token
NS=kubernetes-dashboard
TOKEN="$(kubectl -n $NS describe secret $(kubectl -n $NS get secret | awk '/admin-user/ {print $1}'))"
log "Kubernetes Dashboard Token"
logc "\n$(echo "$TOKEN" | awk '/token:/ {print $2}')\n"

log "Waiting for all cluster pods to attain 'Ready' status ...."
# Query `kind` cluster for the condition of the deployed pods
kubectl wait pods --for=condition=Ready --all -A --timeout=180s

log "Completed Phase 0c-cluster creation (kind, metalLB, k8s dashboard, ingress) ...."
