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
# Name: install-mlwb.sh - install MLWB components
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

# Default values for Acumos plugins - MLWB
# Edit these values for custom values
MLWB_CORE=$ACUMOS_BASE/acumos-plugins/mlwb
MLWB_CHARTS=$MLWB_CORE/charts
MLWB_GLOBAL_VALUE=$ACUMOS_BASE/mlwb_value.yaml
MLWB_NAMESPACE=$(yq r $MLWB_GLOBAL_VALUE mlwb.namespace)

# Individual MLWB charts (using this format)
# helm install -name $CHARTNAME --namespace $NAMESPACE ./$CHARTNAME/ -f ./global_value.yaml -f ./plugin_value.yaml
# where $CHARTNAME is one of the following charts
#  - project-service
#  - notebook-service
#  - pipeline-service
#  - model-service
#  - predictor-service
#  - dashboard-webcomponent
#  - home-webcomponent
#  - notebook-catalog-webcomponent
#  - notebook-webcomponent
#  - pipeline-catalog-webcomponent
#  - pipeline-webcomponent
#  - project-catalog-webcomponent
#  - project-webcomponent

# Install (or remove) the MLWB charts, one by one in this order
echo "Installing MLWB Project-Service chart ...."
helm install project-service --namespace $MLWB_NAMESPACE $MLWB_CHARTS/project-service/ -f $ACUMOS_GLOBAL_VALUE -f $MLWB_GLOBAL_VALUE

echo "Installing MLWB NoteBook-Service chart ...."
helm install notebook-service --namespace $MLWB_NAMESPACE $MLWB_CHARTS/notebook-service/ -f $ACUMOS_GLOBAL_VALUE -f $MLWB_GLOBAL_VALUE

echo "Installing MLWB Pipeline-Service chart ...."
helm install pipeline-service --namespace $MLWB_NAMESPACE $MLWB_CHARTS/pipeline-service/ -f $ACUMOS_GLOBAL_VALUE -f $MLWB_GLOBAL_VALUE

echo "Installing MLWB Model-Service chart ...."
helm install model-service --namespace $MLWB_NAMESPACE $MLWB_CHARTS/model-service/ -f $ACUMOS_GLOBAL_VALUE -f $MLWB_GLOBAL_VALUE

echo "Installing MLWB Predictor-Service chart ...."
helm install predictor-service --namespace $MLWB_NAMESPACE $MLWB_CHARTS/predictor-service/ -f $ACUMOS_GLOBAL_VALUE -f $MLWB_GLOBAL_VALUE

echo "Installing MLWB Dashboard-WebComponent chart ...."
helm install dashboard-webcomponent --namespace $MLWB_NAMESPACE $MLWB_CHARTS/dashboard-webcomponent/ -f $ACUMOS_GLOBAL_VALUE -f $MLWB_GLOBAL_VALUE

echo "Installing MLWB Home-WebComponent chart ...."
helm install home-webcomponent --namespace $MLWB_NAMESPACE $MLWB_CHARTS/home-webcomponent/ -f $ACUMOS_GLOBAL_VALUE -f $MLWB_GLOBAL_VALUE

echo "Installing MLWB NoteBook-Catalog-WebComponent chart ...."
helm install notebook-catalog-webcomponent --namespace $MLWB_NAMESPACE $MLWB_CHARTS/notebook-catalog-webcomponent/ -f $ACUMOS_GLOBAL_VALUE -f $MLWB_GLOBAL_VALUE

echo "Installing MLWB NoteBook-WebComponent chart ...."
helm install notebook-webcomponent --namespace $MLWB_NAMESPACE $MLWB_CHARTS/notebook-webcomponent/ -f $ACUMOS_GLOBAL_VALUE -f $MLWB_GLOBAL_VALUE

echo "Installing MLWB Pipeline-Catalog-WebComponent chart ...."
helm install pipeline-catalog-webcomponent --namespace $MLWB_NAMESPACE $MLWB_CHARTS/pipeline-catalog-webcomponent/ -f $ACUMOS_GLOBAL_VALUE -f $MLWB_GLOBAL_VALUE

echo "Installing MLWB Pipeline-WebComponent chart ...."
helm install pipeline-webcomponent --namespace $MLWB_NAMESPACE $MLWB_CHARTS/pipeline-webcomponent/ -f $ACUMOS_GLOBAL_VALUE -f $MLWB_GLOBAL_VALUE

echo "Installing MLWB Project-Catalog-WebComponent chart ...."
helm install project-catalog-webcomponent --namespace $MLWB_NAMESPACE $MLWB_CHARTS/project-catalog-webcomponent/ -f $ACUMOS_GLOBAL_VALUE -f $MLWB_GLOBAL_VALUE

echo "Installing MLWB Project-WebComponent chart ...."
helm install project-webcomponent --namespace $MLWB_NAMESPACE $MLWB_CHARTS/project-webcomponent/ -f $ACUMOS_GLOBAL_VALUE -f $MLWB_GLOBAL_VALUE

echo "Finished installing MLWB Helm charts ...."
echo "Success!!! You have successfully installed Acumos and MLWB!"
echo "Please check the status of the newly installed pods to ensure they are all in a 'Running' state."
