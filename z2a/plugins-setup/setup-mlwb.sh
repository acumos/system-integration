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
# Name: setup-mlwb.sh - setup MLWB components
#
# Prerequisites:
# 1. setup-distro.sh ran successfully
# 2. setup-docker.sh ran successfully
# 3. end-user (installer) logged out and back in ('docker' group)
# 4. setup-k8s-helm-kind.sh ran successfully and the kind cluster is running
# 5. setup-acumos-non-core.sh ran successfully and dependencies are installed
# 6: mlwb plugin dependencies ran successfully and dependencies are installed
#		 - setup-couchdb.sh ran successfully
#		 - setup-jupyterhub.sh ran successfully
#		 - setup-nifi.sh ran successfully
#
# Usage:

MLWB_CORE=$Z2A_ACUMOS_BASE/acumos-plugins/mlwb
MLWB_CHARTS=$$MLWB_CORE/charts

# Individual MLWB charts
# helm install -name $CHARTNAME --namespace $NAMESPACE ./$CHARTNAME/ -f ./global_value.yaml
# where $CHARTNAME is one of the following charts
  - project-service
  - notebook-service
  - pipeline-service
  - model-service
  - predictor-service
  - dashboard-webcomponent
  - home-webcomponent
  - notebook-catalog-webcomponent
  - notebook-webcomponent
  - pipeline-catalog-webcomponent
  - pipeline-webcomponent
  - project-catalog-webcomponent
  - project-webcomponent

log "Installing MLWB Helm charts ...."
# Install (or remove) the MLWB charts, one by one in this order
helm install -name project-service --namespace $NAMESPACE $MLWB_CHARTS/project-service/ -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml
helm install -name notebook-service --namespace $NAMESPACE $MLWB_CHARTS/project-service/ -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml
helm install -name pipeline-service --namespace $NAMESPACE $MLWB_CHARTS/project-service/ -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml
helm install -name model-service --namespace $NAMESPACE $MLWB_CHARTS/project-service/ -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml
helm install -name predictor-service --namespace $NAMESPACE $MLWB_CHARTS/project-service/ -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml
helm install -name dashboard-webcomponent --namespace $NAMESPACE $MLWB_CHARTS/project-service/ -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml
helm install -name home-webcomponent --namespace $NAMESPACE $MLWB_CHARTS/project-service/ -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml
helm install -name notebook-catalog-webcomponent --namespace $NAMESPACE $MLWB_CHARTS/project-service/ -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml
helm install -name notebook-webcomponent --namespace $NAMESPACE $MLWB_CHARTS/project-service/ -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml
helm install -name pipeline-catalog-webcomponent --namespace $NAMESPACE $MLWB_CHARTS/project-service/ -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml
helm install -name pipeline-webcomponent --namespace $NAMESPACE $MLWB_CHARTS/project-service/ -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml
helm install -name project-catalog-webcomponent --namespace $NAMESPACE $MLWB_CHARTS/project-service/ -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml
helm install -name project-webcomponent --namespace $NAMESPACE $MLWB_CHARTS/project-service/ -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml

log "$(Finshed installing MLWB Helm charts ....)"
log "$(Success!!! You have successfully installed Acumos and MLWB!)"