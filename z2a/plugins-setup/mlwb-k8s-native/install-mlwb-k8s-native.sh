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
# Name: install-mlwb-k8s-native.sh - install MLWB components (new k8s-native charts)
#
# Prerequisites:
# acumos installed and configured
# mlwb plugin dependencies installed and configured
#		 - make couchdb
#		 - make jupyterhub
#		 - make nifi
#
# HERE
HERE=$(realpath $(dirname $0))
source $HERE/utils.sh
setup_logging

# Default values for Acumos plugins - MLWB
# Edit these values for custom values
MLWB_CORE=$ACUMOS_BASE/acumos-plugins
MLWB_CHART=$MLWB_CORE/mlwb-k8s-native
MLWB_GLOBAL_VALUE=$ACUMOS_BASE/mlwb_value.yaml
MLWB_NAMESPACE=$(yq r $MLWB_GLOBAL_VALUE mlwb.namespace)

# You can install/upgrade individual MLWB charts (using this format)
# helm upgrade --install -name $CHARTNAME --namespace $NAMESPACE ./$CHARTNAME/ -f ./global_value.yaml -f ./plugin_value.yaml
# where $CHARTNAME is one of the following components
#  - dashboard-webcomponent
#  - datasource-catalog-webcomponent
#  - datasource-service
#  - datasource-webcomponent
#  - home-webcomponent
#  - model-service
#  - notebook-service
#  - notebook-catalog-webcomponent
#  - notebook-webcomponent
#  - pipeline-catalog-webcomponent
#  - pipeline-service
#  - pipeline-webcomponent
#  - predictor-service
#  - project-catalog-webcomponent
#  - project-service
#  - project-webcomponent

# Install (or upgrade) the MLWB
log "Installing MLWB components ...."
helm install mlwb-k8s-native --namespace $MLWB_NAMESPACE $MLWB_CHART/ -f $ACUMOS_GLOBAL_VALUE -f $MLWB_GLOBAL_VALUE

log "Finished installing MLWB components ...."
log "Success!!! You have successfully installed Acumos and MLWB!"
log "Please check the status of the newly installed pods to ensure they are all in a 'Running' state."

# write out logfile name
success
