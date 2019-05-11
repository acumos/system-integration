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

export MLWB_PROJECT_SERVICE_IMAGE=$ACUMOS_SNAPSHOT/project-service:1.0.1-SNAPSHOT
export MLWB_NOTEBOOK_SERVICE_IMAGE=$ACUMOS_SNAPSHOT/notebook-service:1.0.1-SNAPSHOT
export MLWB_PIPELINE_SERVICE_IMAGE=$ACUMOS_SNAPSHOT/pipeline-service:1.0.1-SNAPSHOT
export MLWB_HOME_WEBCOMPONENT_IMAGE=$ACUMOS_SNAPSHOT/home-webcomponent:1.0.5-SNAPSHOT
export MLWB_DASHBOARD_WEBCOMPONENT_IMAGE=$ACUMOS_SNAPSHOT/dashboard-webcomponent:1.0.5-SNAPSHOT
export MLWB_PROJECT_WEBCOMPONENT_IMAGE=$ACUMOS_SNAPSHOT/project-webcomponent:1.0.5-SNAPSHOT
export MLWB_NOTEBOOK_WEBCOMPONENT_IMAGE=$ACUMOS_SNAPSHOT/notebook-webcomponent:1.0.5-SNAPSHOT
export MLWB_PIPELINE_WEBCOMPONENT_IMAGE=$ACUMOS_SNAPSHOT/pipeline-webcomponent:1.0.5-SNAPSHOT
export MLWB_PROJECT_CATALOG_WEBCOMPONENT_IMAGE=$ACUMOS_SNAPSHOT/project-catalog-webcomponent:1.0.5-SNAPSHOT
export MLWB_NOTEBOOK_CATALOG_WEBCOMPONENT_IMAGE=$ACUMOS_SNAPSHOT/notebook-catalog-webcomponent:1.0.5-SNAPSHOT
export MLWB_PIPELINE_CATALOG_WEBCOMPONENT_IMAGE=$ACUMOS_SNAPSHOT/pipeline-catalog-webcomponent:1.0.5-SNAPSHOT

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
export MLWB_JUPYTERHUB_STOREPASS=

export MLWB_NIFI_REGISTRY_PV_NAME="pv-$ACUMOS_NAMESPACE-nifi-registry"
export MLWB_NIFI_REGISTRY_PV_SIZE=5Gi
export MLWB_NIFI_REGISTRY_INITIAL_ADMIN="nifiadmin"
export MLWB_NIFI_REGISTRY_INITIAL_ADMIN_NAME="nifiadmin user"
export MLWB_NIFI_REGISTRY_INITIAL_ADMIN_EMAIL="nifiadmin@$ACUMOS_DOMAIN.org"
export MLWB_NIFI_REGISTRY_INITIAL_ADMIN_PASSWORD=
export MLWB_NIFI_KEYSTORE_PASSWORD=
export MLWB_NIFI_TRUSTSTORE_PASSWORD=
