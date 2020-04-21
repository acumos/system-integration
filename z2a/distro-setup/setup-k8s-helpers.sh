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
# Name: setup-k8s-helpers.sh - script to setup k8s helper applications
#
# Prerequisites:
# 1. setup-distro.sh has been ran successfully
# 2. setup-docker.sh has been ran successfully
# 3. end-user (installer) has logged out and back in ('docker' group)
#
# Usage:

log "Building k8s-svc-proxy local image ...."
# Build local image of the k8s-svc-proxy
(cd $Z2A_BASE/k8s-svc-proxy ; docker build -t k8s-svc-proxy:v1.0 .)

log "Loading k8s-svc-proxy image into kind cluster ...."
# Load image into kind
kind load docker-image k8s-svc-proxy:v1.0 --name $Z2A_CLUSTER_NAME

log "Deploying k8s-svc-proxy pod cluster ...."
# Deploy the k8s-svc-proxy pod
# kubectl apply -f $Z2A_BASE/k8s-svc-proxy/z2a-svcs-proxy.yaml --namespace=$Z2A_K8S_NAMESPACE
helm install z2a-svcs-proxy --namespace=$Z2A_K8S_NAMESPACE ./z2a-svcs-proxy/ -f $Z2A_BASE/z2a-config/z2a_value.yaml

log "Install MetalLB ...."
# Install MetalLB load Balancer
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.9.3/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.9.3/manifests/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

log "Configuring MetalLB ...."
kubectl apply -f $Z2A_BASE/k8s-metallb/metallb.yaml --namespace=metallb-system

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
# Create k8s Cluster Role Binding
kubectl apply -f $Z2A_BASE/k8s-dashboard/clusterrolebinding.yaml

log "Capturing Kubernetes Cluster Status ...."
# Capture k8s cluster status
kubectl get all -A

log "Capturing Default Bearer Token ...."
# Get the Default Bearer Token
NS=kubernetes-dashboard
TOKEN="$(kubectl -n $NS describe secret $(kubectl -n $NS get secret | awk '/admin-user/ {print $1}'))"
log "Kubernetes Dashboard Token"
logc "\n$(echo "$TOKEN" | awk '/token:/ {print $2}')\n"

