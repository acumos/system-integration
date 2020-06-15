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
# Name: 2-plugins.sh - z2a 2-plugins setup script
#
# Prerequisites:
# - Ubuntu Xenial (16.04), Bionic (18.04), or Centos 7 VM
#
# - It is assumed, that the user running this script:
#		- has sudo access on the VM
#		- has successfully completed the 1-acumos installation step OR
#			has installed Acumos by other methods
#
# - Note: to run this script stand-alone,
#   run 0-kind/0a-env.sh to setup the environment first
#

# Anchor Z2A_BASE
HERE=$(realpath $(dirname $0))
Z2A_BASE=$(realpath $HERE/..)
# Source the z2a utils file
source $Z2A_BASE/z2a-utils.sh
# Load user environment
load_env
# Exit with an error on any non-zero return code
# trap 'fail' ERR
set -e

export ACUMOS_BASE=$Z2A_ACUMOS_BASE
export MLWB_GLOBAL_VALUE=$Z2A_ACUMOS_BASE/mlwb_value.yaml
MLWB_NAMESPACE=$(yq r $MLWB_GLOBAL_VALUE mlwb.namespace)
NAMESPACE=$(yq r $ACUMOS_GLOBAL_VALUE global.namespace)

# Create namespace for the MLWB plugins
echo "Starting 2-plugins installation ...."
echo "Creating k8s namespace : name = $MLWB_NAMESPACE"
# Create an namespace in the kind-acumos cluster (default: mlwb)
#TODO: add logic to determine if this namespace exists
kubectl create namespace $MLWB_NAMESPACE

# Test to ensure that all Pods are running before proceeding
# kubectl wait pods --for=condition=Ready --all --namespace=$MLWB_NAMESPACE --timeout=900s

echo "Starting 2-plugins dependency installation ...."
# Installation - MLWB plugin dependencies

echo "Starting MLWB dependency - CouchDB installation ...."
# Installation - MLWB plugin dependencies
(cd $Z2A_BASE/plugins-setup/ ; make couchdb)

echo "Starting MLWB dependency - JupyterHub installation ...."
# Installation - MLWB plugin dependencies
(cd $Z2A_BASE/plugins-setup/ ; make jupyterhub)

echo "Starting MLWB dependency - NiFi installation ...."
# Installation - MLWB plugin dependencies
(cd $Z2A_BASE/plugins-setup/ ; make nifi)

echo "Starting 2-plugins installation ...."
# Installation - Machine Learning WorkBench (MLWB)
echo "Installing MLWB Components ...."
(cd $Z2A_BASE/plugins-setup/ ; make mlwb)
