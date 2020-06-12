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
# Name: install-config-helper.sh    - helper script to install k8s config-helper pod

# Anchor the base directory for the util.sh helper
HERE=$(dirname $(readlink -f $0))
source $HERE/utils.sh
redirect_to $HERE/install.log

# Acumos Global Values Location
GV=$ACUMOS_GLOBAL_VALUE

# Acquire NAMESPACE and RELEASE values
NAMESPACE=$(gv_read global.namespace)
# TODO: add global_value for configHelperRelease
# RELEASE=$(gv_read global.configHelperRelease)
RELEASE=config-helper

log "Installing k8s config-helper Chart ...."
# K8s config-helper Pod Deployment
helm install $RELEASE -n $NAMESPACE $HERE/config-helper/ -f $ACUMOS_GLOBAL_VALUE \
  --set global.namespace=$NAMESPACE \
  --set-string kubeconfig="$(kubectl config view --flatten --minify | base64 -w0)"

log "Waiting .... (up to 15 minutes) for pod ready status ...."
# Wait for the Nexus pods to become available
wait_for_pod_ready 900 $RELEASE