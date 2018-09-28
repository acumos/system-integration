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
# This configuration is for the multi-node configuration

# Acumos project Registries
export ACUMOS_PROJECT_NEXUS_USERNAME=
export ACUMOS_PROJECT_NEXUS_PASSWORD=
# Should ONLY use Staging, if Release version not available or compatible
export STAGING=nexus3.acumos.org:10004
# Should ONLY use Release version
export RELEASE=nexus3.acumos.org:10002

# Host_Names
export ACUMOS_HOST=
export ACUMOS_HOST_FQN=
export ACUMOS_ELK_HOST=
#export ACUMOS_DOMAIN=$(hostname)

# Platform_Components
export COMMON_DATASERVICE_IMAGE=$RELEASE/common-dataservice:1.18.1
export PORTAL_BE_IMAGE=$STAGING/acumos-portal-be:1.15.47
export PORTAL_FE_IMAGE=$STAGING/acumos-portal-fe:1.15.47
export ONBOARDING_IMAGE=$STAGING/onboarding-app:1.36.1
export MICROSERVICE_GENERATION_IMAGE=$STAGING/microservice-generation:1.5.1
export DESIGNSTUDIO_IMAGE=$STAGING/ds-compositionengine:0.0.40
export PORTAL_CMS_IMAGE=$STAGING/acumos-cms-docker:1.3.4
export AZURE_CLIENT_IMAGE=$STAGING/acumos-azure-client:1.2.21
export OPENSTACK_CLIENT_IMAGE=$STAGING/openstack-client:1.1.21
export BLUEPRINT_ORCHESTRATOR_IMAGE=$STAGING/blueprint-orchestrator:2.0.11
export FILEBEAT_IMAGE=$STAGING/acumos-filebeat:1.18.1
export METRICBEAT_IMAGE=$STAGING/acumos-metricbeat:1.18.1
export PROTO_VIEWER_IMAGE=$STAGING/acumos-proto-viewer:1.5.5
export FEDERATION_IMAGE=$STAGING/federation-gateway:1.18.4

#  Model Execution Components
export ONBOARDING_BASE_IMAGE=$STAGING/onboarding-base-r:1.0
export ACUMOS_DATABROKER_URL=$STAGING/sqldatabroker:0.0.2
export DATABROKER_ZIPBROKER_IMAGE=$STAGING/databroker-zipbroker:0.0.1
export DATABROKER_CSVBROKER_IMAGE=$STAGING/csvdatabroker:0.0.4
export H2O_GENERICJAVA_MODELRUNNER__IMAGE=$STAGING/h2o-genericjava-modelrunner-2.2.3


# Onboarding CLI URL
export ACUMOS_ONBOARDING_PORT=8090
export ACUMOS_CLIPUSHURL=$ACUMOS_HOST_FQN:$ACUMOS_ONBOARDING_PORT:8090

# External component options
export ACUMOS_DOCKER_API_HOST=$ACUMOS_DOMAIN
export ACUMOS_DOCKER_API_PORT=2375
export ACUMOS_DOCKER_USERNAME=
export ACUMOS_DOCKER_PASSWORD=
export ACUMOS_NEXUS_USERNAME=
export ACUMOS_NEXUS_PASSWORD=
export ACUMOS_NEXUS_PORT=18003
#export ACUMOS_NEXUS_ADMIN_PASSWORD=
#export ACUMOS_NEXUS_ADMIN_USERNAME=
export ACUMOS_NEXUS_API_PORT=8081
export ACUMOS_NEXUS_HOST=
export ACUMOS_RO_USER=
export ACUMOS_RW_USER=
export ACUMOS_DOCKER_MODEL_PORT=30882

export HTTP_PROXY="http://${ACUMOS_HOST}:3128"
export HTTPS_PROXY=""

# Component options
export ACUMOS_AZURE_CLIENT_PORT=9081
export ACUMOS_CDS_NAME=acumosist_1_18_0
export ACUMOS_CDS_DB=acumosist_1_18_0
export ACUMOS_CDS_HOST=
export ACUMOS_CDS_PORT=3306
export ACUMOS_CDS_USER=
export ACUMOS_CDS_PASS=
export ACUMOS_CDS_DATASOURCE_USER=
export ACUMOS_CMS_DB=
export ACUMOS_CMS_USER=
export ACUMOS_CMS_PASS=
export ACUMOS_CMS_HOST=$ACUMOS_CDS_HOST
export ACUMOS_CMS_PORT=$ACUMOS_CDS_PORT
export ACUMOS_DSCE_PORT=8088
export ACUMOS_FEDERATION_HOST=$ACUMOS_DOMAIN
export ACUMOS_FEDERATION_LOCAL_PORT=9011
export ACUMOS_FEDERATION_PORT=30984
export ACUMOS_FEDERATION_KEY_STORE_PWD=
export ACUMOS_FEDERATION_KEY_PWD=
export ACUMOS_FILEBEAT_PORT=8099
export ACUMOS_ELK_ELASTICSEARCH_HOST=elasticsearch-service
export ACUMOS_ELK_ELASTICSEARCH_PORT=9200
export ACUMOS_ELK_NODEPORT=30930
export ACUMOS_ELK_LOGSTASH_HOST=logstash-service
export ACUMOS_ELK_LOGSTASH_PORT=5000
export ACUMOS_ELK_KIBANA_PORT=5601
export ACUMOS_ELK_KIBANA_NODEPORT=30561
export ACUMOS_ELK_ES_JAVA_HEAP_MIN_SIZE=1g
export ACUMOS_ELK_ES_JAVA_HEAP_MAX_SIZE=2g
export ACUMOS_ELK_LS_JAVA_HEAP_MIN_SIZE=1g
export ACUMOS_ELK_LS_JAVA_HEAP_MAX_SIZE=2g
export ACUMOS_MARIADB_HOST=$ACUMOS_HOST
export ACUMOS_METRICBEAT_PORT=8098
export ACUMOS_MICROSERVICE_GENERATION_PORT=8091
export ACUMOS_OPERATOR_ID=acumos-aio
export ACUMOS_PORTAL_BE_PORT=8083
export ACUMOS_PORTAL_FE_PORT=8085
export ACUMOS_PROBE_PORT=5006
export ACUMOS_VALIDATION_CLIENT_PORT=9603
export ACUMOS_VALIDATION_ENGINE_PORT=9605
export ACUMOS_VALIDATION_MIDDLEWARE_PORT=9604
export PYTHON_EXTRAINDEX=
export PYTHON_EXTRAINDEX_HOST=

# Acumos model deployment options

export ACUMOS_DATA_BROKER_INTERNAL_PORT=8080
export ACUMOS_DATA_BROKER_PORT=8556
export ACUMOS_DEPLOYED_SOLUTION_PORT=8336
export ACUMOS_DEPLOYED_VM_PASSWORD=
export ACUMOS_DEPLOYED_VM_USER=
export ACUMOS_PROBE_PORT=5006



# Features
export VALIDATE_MODEL=true
export EMAIL_SERVICE=
export CAS_ENABLE=false
export VERIFY_ACCOUNT=true
export TOKEN_EXP_TIME=24
                                           
exec docker-compose $*                                          
