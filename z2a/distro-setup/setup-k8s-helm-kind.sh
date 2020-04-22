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

log "Installing kubectl binary ...."
# Download and install kubectl
K8S_RELEASE=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
sudo curl -L -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$K8S_RELEASE/bin/linux/amd64/kubectl
sudo chmod 755 /usr/local/bin/kubectl

log "Installing Helm v3 ...."
# Download and install helm v3 (to /usr/local/bin)
HELM_RELEASE=$(curl -Ls https://github.com/helm/helm/releases| awk '$0 ~ pat {print gensub(/.*".*\/(.*)".*/, "\\1","g");exit}' pat='href="/helm/helm/releases/tag/v3')
sudo curl -s https://get.helm.sh/helm-${HELM_RELEASE}-linux-amd64.tar.gz | tar -zxO linux-amd64/helm > /usr/local/bin/helm
sudo chmod 755 /usr/local/bin/helm

log "Initializing official Helm stable chart repo ...."
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
log "\n\n$(kubectl cluster-info --context kind-$Z2A_CLUSTER_NAME)\n"

log "Creating k8s namespace : name = $Z2A_K8S_NAMESPACE"
# Create an acumos-dev1 namespace in the kind-acumos cluster
kubectl create namespace $Z2A_K8S_NAMESPACE
