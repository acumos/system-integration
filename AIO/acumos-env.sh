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

# Version of the AIO toolset
export ACUMOS_AIO_VERSION=1.0.0

# Acumos project Registries
export ACUMOS_PROJECT_NEXUS_USERNAME=docker
export ACUMOS_PROJECT_NEXUS_PASSWORD=docker
# Should NOT need to use Snapshot
export SNAPSHOT=nexus3.acumos.org:10003
# Should ONLY use Staging, if Release version not available or compatible
export STAGING=nexus3.acumos.org:10004
# Should ONLY use Release version
export RELEASE=nexus3.acumos.org:10002

# Images per https://wiki.acumos.org/display/REL/Weekly+Assembly+Acumos_1810050030
# with updates:
# kubernetes-client:1.1.0-SNAPSHOT
export PORTAL_BE_IMAGE=$STAGING/acumos-portal-be:1.16.1
export PORTAL_FE_IMAGE=$STAGING/acumos-portal-fe:1.16.1
export AZURE_CLIENT_IMAGE=$STAGING/acumos-azure-client:1.2.22
export DESIGNSTUDIO_IMAGE=$STAGING/ds-compositionengine:1.40.1
export PORTAL_CMS_IMAGE=$STAGING/acumos-cms-docker:1.3.4
export ONBOARDING_IMAGE=$STAGING/onboarding-app:1.38.0
export COMMON_DATASERVICE_IMAGE=$STAGING/common-dataservice:1.18.2
export OPENSTACK_CLIENT_IMAGE=$STAGING/openstack-client:1.1.22
export BLUEPRINT_ORCHESTRATOR_IMAGE=$STAGING/blueprint-orchestrator:2.0.11
export FEDERATION_IMAGE=$STAGING/federation-gateway:1.18.5
export KUBERNETES_CLIENT_IMAGE=$STAGING/kubernetes-client:1.1.0
#export ELASTICSEARCH_IMAGE=$STAGING/acumos-elasticsearch:1.18.1
export ELASTICSEARCH_IMAGE=docker.elastic.co/elasticsearch/elasticsearch:5.5.1
export LOGSTASH_IMAGE=$STAGING/acumos-logstash:1.18.2
export KIBANA_IMAGE=$STAGING/acumos-kibana:1.18.2
export FILEBEAT_IMAGE=$STAGING/acumos-filebeat:1.18.2
export METRICBEAT_IMAGE=$STAGING/acumos-metricbeat:1.18.2
export PROTO_VIEWER_IMAGE=$STAGING/acumos-proto-viewer:1.5.6
export MICROSERVICE_GENERATION_IMAGE=$STAGING/microservice-generation:1.7.1
export H2O_GENERICJAVA_MODELRUNNER_IMAGE=$STAGING/h2o-genericjava-modelrunner-2.2.3
export ONBOARDING_BASE_IMAGE=$STAGING/onboarding-base-r:1.0
export DATABROKER_SQLBROKER_IMAGE=$STAGING/sqldatabroker:1.2.0
export DATABROKER_ZIPBROKER_IMAGE=$STAGING/databroker-zipbroker:0.0.1
export DATABROKER_CSVBROKER_IMAGE=$STAGING/csvdatabroker:1.4.0

export ACUMOS_DOMAIN=$(hostname)
# Hard-code ACUMOS_HOST below to the primary IP address (as primary route) of
# your AIO host server, if the generated value does not work for your server
# (there have been reports that this command does not always work)
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
export HTTP_PROXY=""
export HTTPS_PROXY=""

# Component options
export ACUMOS_AZURE_CLIENT_PORT=9081
export ACUMOS_CDS_PREVIOUS_VERSION=
export ACUMOS_CDS_VERSION=1.18
export ACUMOS_CDS_DB="acumos_cds"
export ACUMOS_CDS_HOST=$ACUMOS_DOMAIN
export ACUMOS_CDS_PORT=30800
export ACUMOS_CDS_USER=ccds_client
export ACUMOS_CMS_HOST=$ACUMOS_DOMAIN
export ACUMOS_CMS_PORT=30980
export ACUMOS_DOCKER_PROXY_HOST=$ACUMOS_DOMAIN
export ACUMOS_DOCKER_PROXY_PORT=30883
export ACUMOS_DOCKER_PROXY_USERNAME=
export ACUMOS_DOCKER_PROXY_PASSWORD=
export ACUMOS_DSCE_PORT=8088
export ACUMOS_FEDERATION_HOST=$ACUMOS_DOMAIN
export ACUMOS_FEDERATION_LOCAL_PORT=9011
export ACUMOS_FEDERATION_PORT=30984
export ACUMOS_FILEBEAT_PORT=8099
export ACUMOS_ELK_ELASTICSEARCH_HOST=elasticsearch-service
export ACUMOS_ELK_ELASTICSEARCH_PORT=9200
export ACUMOS_ELK_NODEPORT=30930
export ACUMOS_ELK_LOGSTASH_HOST=logstash-service
export ACUMOS_ELK_LOGSTASH_PORT=5000
export ACUMOS_ELK_KIBANA_HOST=$ACUMOS_DOMAIN
export ACUMOS_ELK_KIBANA_PORT=5601
export ACUMOS_ELK_KIBANA_NODEPORT=30561
export ACUMOS_ELK_ES_JAVA_HEAP_MIN_SIZE=1g
export ACUMOS_ELK_ES_JAVA_HEAP_MAX_SIZE=2g
export ACUMOS_ELK_LS_JAVA_HEAP_MIN_SIZE=1g
export ACUMOS_ELK_LS_JAVA_HEAP_MAX_SIZE=2g
export ACUMOS_KUBERNETES_CLIENT_PORT=8082
export ACUMOS_MARIADB_HOST=$ACUMOS_HOST
export ACUMOS_MARIADB_PORT=3306
export ACUMOS_METRICBEAT_PORT=8098
export ACUMOS_MICROSERVICE_GENERATION_PORT=8336
export ACUMOS_ONBOARDING_PORT=8090
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
export ACUMOS_DEPLOYED_SOLUTION_PORT=3330
export ACUMOS_DEPLOYED_VM_PASSWORD='12NewPA$$w0rd!'
export ACUMOS_DEPLOYED_VM_USER=dockerUser
export ACUMOS_PROBE_PORT=5006
