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
# - Intended to be called from oneclick_deploy.sh and docker-compose.sh
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
export COMMON_DATASERVICE_IMAGE=$RELEASE/common-dataservice:1.14.3
export ONBOARDING_IMAGE=$STAGING/onboarding-app:1.18.1
export PORTAL_BE_IMAGE=$STAGING/acumos-portal-be:1.14.50
export PORTAL_FE_IMAGE=$STAGING/acumos-portal-fe:1.14.50
export PORTAL_CMS_IMAGE=$STAGING/acumos-cms-docker:1.3.2
export DESIGNSTUDIO_IMAGE=$STAGING/ds-compositionengine:0.0.23
export FEDERATION_IMAGE=$STAGING/federation-gateway:1.1.1
export FILEBEAT_IMAGE=$STAGING/acumos-filebeat:1.0.0
export AZURE_CLIENT_IMAGE=$STAGING/acumos-azure-client:1.81.0
export DATABROKER_ZIPBROKER_IMAGE=$STAGING/databroker-zipbroker:0.0.1
export VALIDATION_CLIENT_IMAGE=$STAGING/validation-client:1.2.1
export VALIDATION_MIDDLEWARE_IMAGE=$STAGING/validation-middleware:1.2.1
export VALIDATION_ENGINE_IMAGE=$STAGING/validation-engine:1.2.2

export ACUMOS_DOMAIN=$(hostname)
host=$(ip route get 8.8.8.8 | awk '{print $NF; exit}')
export ACUMOS_HOST=$host
export ACUMOS_HOSTNAME=localhost
export ACUMOS_CDS_VERSION=1.14
export ACUMOS_CDS_DB="acumos_1_14"
export ACUMOS_MARIADB_HOST=$host
export ACUMOS_MARIADB_PORT=3306
# TODO: Various components hardcode user name ccds_client
export ACUMOS_CDS_USER=ccds_client
export ACUMOS_CDS_HOST=$host
export ACUMOS_CDS_PORT=8000
export ACUMOS_NEXUS_HOST=$host
export ACUMOS_MAVEN_MODEL_PORT=8001
export ACUMOS_DOCKER_MODEL_PORT=8002
export ACUMOS_DOCKER_PLATFORM_PORT=8003
export ACUMOS_NEXUS_API_PORT=8081
export ACUMOS_PORTAL_BE_HOST=$host
export ACUMOS_PORTAL_BE_PORT=8083
export ACUMOS_PORTAL_FE_HOST=$host
export ACUMOS_PORTAL_FE_HOSTNAME=$ACUMOS_DOMAIN
export ACUMOS_PORTAL_FE_PORT=8085
export ACUMOS_TOSCA_PYTHON_HOST=$host
export ACUMOS_TOSCA_PYTHON_PORT=8080
export ACUMOS_DSCE_HOST=$host
export ACUMOS_DSCE_PORT=8088
export ACUMOS_ONBOARDING_HOST=$host
export ACUMOS_ONBOARDING_PORT=8090
export ACUMOS_CMS_HOST=$host
export ACUMOS_CMS_PORT=9080
export ACUMOS_AZURE_CLIENT_HOST=$host
export ACUMOS_AZURE_CLIENT_PORT=9081
export ACUMOS_PLATON_HOST=$host
export ACUMOS_PLATON_PORT=9083
export ACUMOS_FEDERATION_HOST=$host
export ACUMOS_FEDERATION_PORT=9084
export ACUMOS_FEDERATION_LOCAL_PORT=9011
export ACUMOS_VALIDATION_CLIENT_PORT=9602
export ACUMOS_VALIDATION_MIDDLEWARE_PORT=9604
export ACUMOS_VALIDATION_ENGINE_PORT=9605
export ACUMOS_KONG_DB_PORT=5432
export ACUMOS_KONG_PROXY_PORT=80
export ACUMOS_KONG_PROXY_SSL_PORT=443
export ACUMOS_KONG_ADMIN_HOST=localhost
export ACUMOS_KONG_ADMIN_PORT=8480
export ACUMOS_KONG_ADMIN_SSL_PORT=8443
export ACUMOS_DOCKER_API_HOST=$host
export PYTHON_EXTRAINDEX=
export PYTHON_EXTRAINDEX_HOST=
