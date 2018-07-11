#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
# What this is: Environment file for Acumos installation.
# Prerequisites:
# - Ubuntu Xenial or Centos 7 server
# Usage:
# - Intended to be called from oneclick_deploy.sh and other scripts in this repo
#

# Registries
# Should NOT need to use Snapshot
export SNAPSHOT=nexus3.acumos.org:10003
# Should ONLY use Staging, if Release version not available or compatible
export STAGING=nexus3.acumos.org:10004
# Should ONLY use Release version
export RELEASE=nexus3.acumos.org:10002

# Images
# If images are not found, goto https://nexus3.acumos.org and browse the
# docker.staging folder for the specific component, and verify the version
export COMMON_DATASERVICE_IMAGE=$STAGING/common-dataservice:1.14.4
export ONBOARDING_IMAGE=$STAGING/onboarding-app:1.27.0
export ONBOARDING_BASE_IMAGE=$STAGING/onboarding-base-r:1.0
export PORTAL_BE_IMAGE=$STAGING/acumos-portal-be:1.15.33
export PORTAL_FE_IMAGE=$STAGING/acumos-portal-fe:1.15.33
export PORTAL_CMS_IMAGE=$STAGING/acumos-cms-docker:1.3.4
export DESIGNSTUDIO_IMAGE=$STAGING/ds-compositionengine:0.0.30
export FEDERATION_IMAGE=$STAGING/federation-gateway:1.1.2
export FILEBEAT_IMAGE=$STAGING/acumos-filebeat:1.0.0
export METRICBEAT_IMAGE=$STAGING/acumos-metricbeat:1.0.0
export AZURE_CLIENT_IMAGE=$STAGING/acumos-azure-client:1.2.4
export VALIDATION_CLIENT_IMAGE=$STAGING/validation-client:1.2.1
export VALIDATION_MIDDLEWARE_IMAGE=$STAGING/validation-middleware:1.2.1
export VALIDATION_ENGINE_IMAGE=$STAGING/validation-engine:1.2.2
export BLUEPRINT_ORCHESTRATOR_IMAGE=$STAGING/blueprint-orchestrator:1.0.7
export DATABROKER_ZIPBROKER_IMAGE=$STAGING/databroker-zipbroker:0.0.1
export DATABROKER_CSVBROKER_IMAGE=$STAGING/csvdatabroker:0.0.1
export PROTO_VIEWER_IMAGE=$SNAPSHOT/acumos_proto_viewer:1.4.1
export ACUMOS_PROJECT_NEXUS_USERNAME=docker
export ACUMOS_PROJECT_NEXUS_PASSWORD=docker


export ACUMOS_DOMAIN=$(hostname)
host=$(ip route get 8.8.8.8 | awk '{print $NF; exit}')
export ACUMOS_HOST=$host

# External component options
export ACUMOS_DOCKER_API_HOST=$ACUMOS_DOMAIN
export ACUMOS_DOCKER_API_PORT=2375
export ACUMOS_NEXUS_ADMIN_PASSWORD=admin123
export ACUMOS_NEXUS_ADMIN_USERNAME=admin
export ACUMOS_NEXUS_API_PORT=30881
export ACUMOS_NEXUS_HOST=$ACUMOS_DOMAIN
export ACUMOS_RO_USER=acumos_ro
export ACUMOS_RW_USER=acumos_rw
export ACUMOS_DOCKER_MODEL_PORT=30882
export ACUMOS_KONG_ADMIN_HOST=$ACUMOS_DOMAIN
export ACUMOS_KONG_ADMIN_PORT=30081
export ACUMOS_KONG_ADMIN_SSL_PORT=30444
export ACUMOS_KONG_DB_PORT=5432
export ACUMOS_KONG_PROXY_PORT=30080
export ACUMOS_KONG_PROXY_SSL_PORT=30443

# Component options
export ACUMOS_AZURE_CLIENT_HOST=$ACUMOS_DOMAIN
export ACUMOS_AZURE_CLIENT_PORT=9081
export ACUMOS_CDS_VERSION=1.14
export ACUMOS_CDS_DB="acumos_1_14"
export ACUMOS_CDS_HOST=$ACUMOS_DOMAIN
export ACUMOS_CDS_PORT=30800
export ACUMOS_CDS_USER=ccds_client
export ACUMOS_CMS_HOST=$ACUMOS_DOMAIN
export ACUMOS_CMS_PORT=30980
export ACUMOS_DSCE_HOST=$ACUMOS_DOMAIN
export ACUMOS_DSCE_PORT=8088
export ACUMOS_FEDERATION_HOST=$ACUMOS_DOMAIN
export ACUMOS_FEDERATION_LOCAL_PORT=9011
export ACUMOS_FEDERATION_PORT=30984
export ACUMOS_MARIADB_HOST=$ACUMOS_HOST
export ACUMOS_MARIADB_PORT=3306
export ACUMOS_ONBOARDING_HOST=$ACUMOS_DOMAIN
export ACUMOS_ONBOARDING_PORT=8090
export ACUMOS_OPERATOR_ID=acumos-aio
export ACUMOS_PLATON_HOST=$ACUMOS_DOMAIN
export ACUMOS_PLATON_PORT=9083
export ACUMOS_PORTAL_BE_HOST=$ACUMOS_DOMAIN
export ACUMOS_PORTAL_BE_PORT=8083
export ACUMOS_PORTAL_FE_HOST=$ACUMOS_DOMAIN
export ACUMOS_PORTAL_FE_HOSTNAME=$ACUMOS_DOMAIN
export ACUMOS_PORTAL_FE_PORT=8085
export ACUMOS_PROBE_PORT=5006
export ACUMOS_TOSCA_PYTHON_HOST=$ACUMOS_DOMAIN
export ACUMOS_TOSCA_PYTHON_PORT=8080
export ACUMOS_VALIDATION_CLIENT_PORT=9603
export ACUMOS_VALIDATION_ENGINE_PORT=9605
export ACUMOS_VALIDATION_MIDDLEWARE_PORT=9604
export PYTHON_EXTRAINDEX=
export PYTHON_EXTRAINDEX_HOST=

# Acumos model deployment options
export ACUMOS_DATA_BROKER_INTERNAL_PORT=8080
export ACUMOS_DATA_BROKER_PORT=8556
export ACUMOS_DEPLOYED_SOLUTION_PORT=8336
export ACUMOS_DEPLOYED_VM_PASSWORD='12NewPA$$w0rd!'
export ACUMOS_DEPLOYED_VM_USER=dockerUser
export ACUMOS_PROBE_PORT=5006
