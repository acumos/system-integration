#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2019 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
# What this is: Environment file for Acumos MLWB installation.
#

# Images based upon Clio release assembly
# https://wiki.acumos.org/display/REL/Weekly+Assembly+Acumos_Clio_1910271600
# plus latest released images
export MLWB_MODEL_SERVICE_IMAGE=$ACUMOS_RELEASE/model-service:2.0.0
export MLWB_NOTEBOOK_SERVICE_IMAGE=$ACUMOS_RELEASE/notebook-service:2.0.1
export MLWB_PIPELINE_SERVICE_IMAGE=$ACUMOS_RELEASE/pipeline-service:2.0.2
export MLWB_PREDICTOR_SERVICE_IMAGE=$ACUMOS_RELEASE/predictor-service:1.0.0
export MLWB_PROJECT_SERVICE_IMAGE=$ACUMOS_RELEASE/project-service:2.0.2
export MLWB_HOME_WEBCOMPONENT_IMAGE=$ACUMOS_RELEASE/acumos/home-webcomponent:2.0.5
export MLWB_DASHBOARD_WEBCOMPONENT_IMAGE=$ACUMOS_RELEASE/acumos/dashboard-webcomponent:2.0.6
export MLWB_PROJECT_WEBCOMPONENT_IMAGE=$ACUMOS_RELEASE/acumos/project-webcomponent:2.0.6
export MLWB_NOTEBOOK_WEBCOMPONENT_IMAGE=$ACUMOS_RELEASE/acumos/notebook-webcomponent:2.0.6
export MLWB_PIPELINE_WEBCOMPONENT_IMAGE=$ACUMOS_RELEASE/acumos/pipeline-webcomponent:2.0.6
export MLWB_PROJECT_CATALOG_WEBCOMPONENT_IMAGE=$ACUMOS_RELEASE/acumos/project-catalog-webcomponent:2.0.7
export MLWB_NOTEBOOK_CATALOG_WEBCOMPONENT_IMAGE=$ACUMOS_RELEASE/acumos/notebook-catalog-webcomponent:2.0.7
export MLWB_PIPELINE_CATALOG_WEBCOMPONENT_IMAGE=$ACUMOS_RELEASE/acumos/pipeline-catalog-webcomponent:2.0.7

export MLWB_PROJECT_SERVICE_PORT=9088
export MLWB_NOTEBOOK_SERVICE_PORT=9089
export MLWB_PIPELINE_SERVICE_PORT=9090
export MLWB_HOME_WEBCOMPONENT_PORT=9087
export MLWB_DASHBOARD_WEBCOMPONENT_PORT=9083
export MLWB_PROJECT_WEBCOMPONENT_PORT=9084
export MLWB_NOTEBOOK_WEBCOMPONENT_PORT=9093
export MLWB_PIPELINE_WEBCOMPONENT_PORT=9091
export MLWB_PROJECT_CATALOG_WEBCOMPONENT_PORT=9085
export MLWB_NOTEBOOK_CATALOG_WEBCOMPONENT_PORT=9094
export MLWB_PIPELINE_CATALOG_WEBCOMPONENT_PORT=9092
export MLWB_JUPYTERHUB_SERVICE_PORT=8086
export MLWB_CORE_SERVICE_LABEL=acumos
export MLWB_PROJECT_SERVICE_LABEL=acumos
export MLWB_NOTEBOOK_SERVICE_LABEL=acumos
export MLWB_PIPELINE_SERVICE_LABEL=acumos

export MLWB_DEPLOY_PIPELINE=true
export MLWB_DEPLOY_NIFI=true
export MLWB_NIFI_CREATE_USER_POD=true
export MLWB_NIFI_EXTERNAL_PIPELINE_SERVICE=false
export MLWB_NIFI_REGISTRY_PV_NAME="nifi-registry"
export MLWB_NIFI_REGISTRY_PVC_NAME="nifi-registry"
export MLWB_NIFI_REGISTRY_PV_SIZE=5Gi
export MLWB_NIFI_REGISTRY_PV_CLASSNAME=$ACUMOS_5GI_STORAGECLASSNAME
export MLWB_NIFI_REGISTRY_INITIAL_ADMIN="nifiadmin"
export MLWB_NIFI_REGISTRY_INITIAL_ADMIN_NAME="nifiadmin user"
export MLWB_NIFI_REGISTRY_INITIAL_ADMIN_EMAIL="nifiadmin@acumos.org"
export MLWB_NIFI_REGISTRY_INITIAL_ADMIN_PASSWORD=
export MLWB_NIFI_KEY_PASSWORD=
export MLWB_NIFI_KEYSTORE_PASSWORD=
export MLWB_NIFI_TRUSTSTORE_PASSWORD=
export MLWB_NIFI_USER_SERVICE_LABEL=acumos

export MLWB_DEPLOY_JUPYTERHUB=true
export MLWB_JUPYTERHUB_EXTERNAL_NOTEBOOK_SERVICE=false
export MLWB_JUPYTERHUB_INSTALL_CERT=true
export MLWB_JUPYTERHUB_IMAGE_TAG=9e8682c9ea54
export MLWB_JUPYTERHUB_NAMESPACE=$ACUMOS_NAMESPACE
export MLWB_JUPYTERHUB_DOMAIN=$ACUMOS_DOMAIN
export MLWB_JUPYTERHUB_PORT=443
export MLWB_JUPYTERHUB_CERT=$ACUMOS_CERT
export MLWB_JUPYTERHUB_API_TOKEN=
export MLWB_JUPYTERHUB_HUB_PV_NAME=jupyterhub-hub
