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
# Name: setup-k8s-helm-kind.sh - script to setup k8s tools, helm and kind
#
# Prerequisites:
# 1. setup-distro.sh has been ran successfully
# 2. setup-docker.sh has been ran successfully
# 3. end-user (installer) has logged out and back in ('docker' group)
#
# Usage:

log "Adding K8s repo ...."
# Add Kubernetes repo to RHEL/Centos
rhel && {
  cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
  sudo yum -y update
}

log "Installing kubectl binary ...."
# Download and install kubectl
# RHEL/Centos
rhel && sudo yum install -y kubectl
# Download and install kubectl
# Ubuntu
ubuntu && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
ubuntu && echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
ubuntu && sudo apt-get update && sudo apt-get install -y kubectl

log "Installing Helm v3 ...."
# Download and install helm v3 (to /usr/local/bin)
sudo curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

log "Initializing official Helm stable chart repo ..."
# Initialize the official helm stable chart repo ; perform update
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo update

log "Installing kind (Kubernetes in Docker) ...."
# Download and install kind (kubernetes in docker)
# kind is NOT DESIGNED FOR PRODUCTION ENVIRONMENTS
sudo curl -Lo /tmp/kind "https://github.com/kubernetes-sigs/kind/releases/download/v0.7.0/kind-$(uname)-amd64"
sudo chmod +x /tmp/kind && sudo chown root:root /tmp/kind
sudo mv /tmp/kind /usr/local/bin/kind

Z2A_CLUSTER_NAME=acumos ; save_env
log "Creating kind cluster : name = $Z2A_CLUSTER_NAME (this may take a few minutes .... relax!!!!)"
# Create kind cluster (named kind-acumos)
kind create cluster --name=$Z2A_CLUSTER_NAME --config $Z2A_BASE/distro-setup/kind-config.yaml
# Echo cluster-info - echo output to both log file and TTY
log "$(kubectl cluster-info --context kind-$Z2A_CLUSTER_NAME)"

Z2A_K8S_NAMESPACE=acumos-dev1 ; save_env
log "Creating k8s namespace : name = $Z2A_K8S_NAMESPACE"
# Create an acumos-dev1 namespace in the kind-acumos cluster
kubectl create namespace $Z2A_K8S_NAMESPACE

log "Building k8s-svc-proxy local image ...."
# Build local image of the k8s-svc-proxy
(cd $Z2A_BASE/k8s-svc-proxy ; docker build -t k8s-svc-proxy:v1.0 .)

log "Loading k8s-svc-proxy image into kind cluster ...."
# Load image into kind
kind load docker-image k8s-svc-proxy:v1.0 --name $Z2A_CLUSTER_NAME

log "Deploying k8s-svc-proxy pod cluster ...."
# Deploy the k8s-svc-proxy pod
kubectl apply -f $Z2A_BASE/k8s-svc-proxy/z2a-svcs-proxy.yaml --namespace=$Z2A_K8S_NAMESPACE

log "Installing the Kubernetes Dashboard ...."
# Download and install the Kubernetes Dashboard
curl -o $Z2A_BASE/k8s-dashboard/recommended.yaml https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-rc7/aio/deploy/recommended.yaml
egrep -v '^\s*#' $Z2A_BASE/k8s-dashboard/recommended.yaml > $Z2A_BASE/k8s-dashboard/main.yaml
yq w -i -d'*' $Z2A_BASE/k8s-dashboard/main.yaml '**.(.==443).' 9090
yq w -i -d'*' $Z2A_BASE/k8s-dashboard/main.yaml '**.(.==8443).' 9090
yq w -i -d'*' $Z2A_BASE/k8s-dashboard/main.yaml '**.(.==HTTPS).' HTTP
yq w -i -d'*' $Z2A_BASE/k8s-dashboard/main.yaml '**.(.==--auto-generate-certificates).' -- '--enable-insecure-login'
kubectl apply -f $Z2A_BASE/k8s-dashboard/main.yaml

log "Creating Kubernetes Dashboard Service Account ...."
# Create Service Account
kubectl apply -f $Z2A_BASE/k8s-dashboard/admin-user.yaml

log "Creating Kubernetes Dashboard ClusterRole Binding ...."
# Create Cluster Role Binding
kubectl apply -f $Z2A_BASE/k8s-dashboard/clusterrolebinding.yaml

log "Capturing Default Bearer Token ...."
# Get the Default Bearer Token
NS=kubernetes-dashboard
TOKEN="$(kubectl -n $NS describe secret $(kubectl -n $NS get secret | awk '/admin-user/ {print $1}'))"
echo "$TOKEN"     # capture to log
log "Kubernetes Dashboard Token"
log $(echo "$TOKEN" | awk '/token:/ {print $2}')
