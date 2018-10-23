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

export ACUMOS_INSTANCE_NAME=

# Acumos project Registries
export ACUMOS_PROJECT_NEXUS_USERNAME=
export ACUMOS_PROJECT_NEXUS_PASSWORD=

# Should ONLY use Staging, if Release version not available or compatible
export STAGING=

# Should ONLY use Release version
export RELEASE=

# Acumos email
export ACUMOS_EMAIL=

#Special for Acumos DC Staging
export ACUMOS_HOST_URL=

# Host_Names
export ACUMOS_HOST=
export ACUMOS_HOST_FQN=
export ACUMOS_ELK_HOST=
export NEXUS_LF_FQM=

# Platform_Components
export COMMON_DATASERVICE_IMAGE=
export PORTAL_BE_IMAGE=
export PORTAL_FE_IMAGE=
export ONBOARDING_IMAGE=
export MICROSERVICE_GENERATION_IMAGE=
export DESIGNSTUDIO_IMAGE=
export PORTAL_CMS_IMAGE=
export AZURE_CLIENT_IMAGE=
export OPENSTACK_CLIENT_IMAGE=
export BLUEPRINT_ORCHESTRATOR_IMAGE=
export FILEBEAT_IMAGE=
export METRICBEAT_IMAGE=
export PROTO_VIEWER_IMAGE=
export FEDERATION_IMAGE=
export KUBERNETES_CLIENT_IMAGE=

# Model Execution Components
export ONBOARDING_BASE_IMAGE=
export ACUMOS_DATABROKER_URL=
export DATABROKER_ZIPBROKER_IMAGE=
export DATABROKER_CSVBROKER_IMAGE=
export H2O_GENERICJAVA_MODELRUNNER__IMAGE=


# Onboarding CLI URL
export ACUMOS_ONBOARDING_PORT=
export ACUMOS_CLIPUSHURL=

# External component options
export ACUMOS_DOCKER_API_HOST=
export ACUMOS_DOCKER_API_PORT=
export ACUMOS_DOCKER_USERNAME=
export ACUMOS_DOCKER_PASSWORD=
export ACUMOS_DOCKER_PORT=
export ACUMOS_NEXUS_USERNAME=
export ACUMOS_NEXUS_PASSWORD=
export ACUMOS_NEXUS_PORT=
export ACUMOS_NEXUS_REPO=
export ACUMOS_NEXUS_API_PORT=
export ACUMOS_NEXUS_HOST=
export ACUMOS_RO_USER=
export ACUMOS_RW_USER=
export ACUMOS_DOCKER_MODEL_PORT=


export HTTP_PROXY=
export HTTPS_PROXY=

# Component options
export ACUMOS_AZURE_CLIENT_PORT=
export ACUMOS_AZURE_DOCKER_PORT=
export ACUMOS_CDS_SERVER_PORT=
export ACUMOS_CDS_DB=
export ACUMOS_CDS_HOST=
export ACUMOS_CDS_PORT=
export ACUMOS_CDS_USER=
export ACUMOS_CDS_PASS=
export ACUMOS_CDS_DATASOURCE_USER=
export ACUMOS_CDS_DATASOURCE_PASS=
export ACUMOS_CMS_DB=
export ACUMOS_CMS_USER=
export ACUMOS_CMS_PASS=
export ACUMOS_CMS_HOST=
export ACUMOS_CMS_PORT=
export ACUMOS_DSCE_PORT=
export ACUMOS_FEDERATION_HOST=
export ACUMOS_FEDERATION_LOCAL_PORT=
export ACUMOS_FEDERATION_PORT=
export ACUMOS_FEDERATION_KEY_STORE=
export ACUMOS_FEDERATION_KEY_STORE_PWD=
export ACUMOS_FEDERATION_KEY_PWD=
export ACUMOS_FEDERATION_KEY_STORE_TYPE=
export ACUMOS_FEDERATION_TRUST_STORE=
export ACUMOS_FEDERATION_TRUST_STORE_PASS=
export ACUMOS_FILEBEAT_PORT=
export ACUMOS_ELK_ELASTICSEARCH_HOST=
export ACUMOS_ELK_ELASTICSEARCH_PORT=
export ACUMOS_ELK_NODEPORT=
export ACUMOS_ELK_LOGSTASH_HOST=
export ACUMOS_ELK_LOGSTASH_PORT=
export ACUMOS_ELK_KIBANA_PORT=
export ACUMOS_ELK_KIBANA_NODEPORT=
export ACUMOS_ELK_ES_JAVA_HEAP_MIN_SIZE=
export ACUMOS_ELK_ES_JAVA_HEAP_MAX_SIZE=
export ACUMOS_ELK_LS_JAVA_HEAP_MIN_SIZE=
export ACUMOS_ELK_LS_JAVA_HEAP_MAX_SIZE=
export ACUMOS_MARIADB_HOST=
export ACUMOS_METRICBEAT_PORT=
export ACUMOS_MICROSERVICE_GENERATION_PORT=
export ACUMOS_OPERATOR_ID=
export ACUMOS_PORTAL_BE_PORT=
export ACUMOS_PORTAL_FE_PORT=
export ACUMOS_PORTAL_PACKAGE_PORT=
export ACUMOS_PROBE_PORT=
export ACUMOS_VALIDATION_CLIENT_PORT=
export ACUMOS_VALIDATION_ENGINE_PORT=
export ACUMOS_VALIDATION_MIDDLEWARE_PORT=
export PYTHON_EXTRAINDEX=
export PYTHON_EXTRAINDEX_HOST=
export ACUMOS_SITE_PORT=
export ACUMOS_CMNT_PORT=
export OPENSTACK_PORT=
export OPENSTACK_URL=
export BLUEPRINT_PORT=
export BLUEPRINT_USERNAME=
export BLUEPRINT_PASS=
export NEXUS_LF_FQM=


# Acumos model deployment options

export ACUMOS_DATA_BROKER_INTERNAL_PORT=
export ACUMOS_DATA_BROKER_PORT=
export ACUMOS_INTERNAL_DATA_BROKER_PORT=
export ACUMOS_DEPLOYED_SOLUTION_PORT=
export ACUMOS_DEPLOYED_VM_PASSWORD=
export ACUMOS_DEPLOYED_VM_USER=
export ACUMOS_PROBE_PORT=



# Features
export VALIDATE_MODEL=
export EMAIL_SERVICE=
export CAS_ENABLE=
export VERIFY_ACCOUNT=
export TOKEN_EXP_TIME=

# MailJet Paremters
export MAILJET_API_KEY=
export MAILJECT_SECRET_KEY=
export MAILJECT_ADDRESS=




exec docker-compose $*
