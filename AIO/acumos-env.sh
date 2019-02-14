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
export ACUMOS_AIO_VERSION=2.0.1

# Acumos project Registries
export ACUMOS_PROJECT_NEXUS_USERNAME=docker
export ACUMOS_PROJECT_NEXUS_PASSWORD=docker
# Should NOT need to use Snapshot
export SNAPSHOT=nexus3.acumos.org:10003
# Should ONLY use Staging, if Release version not available or compatible
export STAGING=nexus3.acumos.org:10004
# Should ONLY use Release version
export RELEASE=nexus3.acumos.org:10002

# Images per Athena 1.0 final release assembly
# https://wiki.acumos.org/display/REL/Weekly+Assembly+Acumos_1810301700
export PORTAL_BE_IMAGE=$RELEASE/acumos-portal-be:1.16.2
export PORTAL_FE_IMAGE=$RELEASE/acumos-portal-fe:1.16.2
export AZURE_CLIENT_IMAGE=$RELEASE/acumos-azure-client:1.2.22
export DESIGNSTUDIO_IMAGE=$RELEASE/ds-compositionengine:1.40.2
export PORTAL_CMS_IMAGE=$RELEASE/acumos-cms-docker:1.3.5
export ONBOARDING_IMAGE=$RELEASE/onboarding-app:1.39.0
export COMMON_DATASERVICE_IMAGE=$RELEASE/common-dataservice:1.18.4
export OPENSTACK_CLIENT_IMAGE=$RELEASE/openstack-client:1.1.22
export BLUEPRINT_ORCHESTRATOR_IMAGE=$RELEASE/blueprint-orchestrator:2.0.11
export FEDERATION_IMAGE=$RELEASE/federation-gateway:1.18.7
export KUBERNETES_CLIENT_IMAGE=$RELEASE/kubernetes-client:1.1.0
export PROTO_VIEWER_IMAGE=$RELEASE/acumos-proto-viewer:1.5.6
export MICROSERVICE_GENERATION_IMAGE=$RELEASE/microservice-generation:1.8.2
export H2O_GENERICJAVA_MODELRUNNER_IMAGE=$RELEASE/h2o-genericjava-modelrunner-2.2.3
export ONBOARDING_BASE_IMAGE=$RELEASE/onboarding-base-r:1.0.0
export DATABROKER_SQLBROKER_IMAGE=$RELEASE/sqldatabroker:1.2.0
export DATABROKER_ZIPBROKER_IMAGE=$RELEASE/databroker-zipbroker:0.0.1
export DATABROKER_CSVBROKER_IMAGE=$RELEASE/csvdatabroker:1.4.0

# Set by oneclick_deploy.sh
export DEPLOYED_UNDER=
export K8S_DIST=
export AIO_ROOT=
export ACUMOS_DOMAIN=
export ACUMOS_HOST=
export ACUMOS_HOST_OS=
export ACUMOS_HOST_OS_VER=
export ACUMOS_ADMIN_HOST=
export ACUMOS_ADMIN_REGISTRY_USER=
export ACUMOS_ADMIN_REGISTRY_PASSWORD=
export DEPLOY_RESULT=
export FAIL_REASON=

# Global options
export SHELL_TRACE=false
export ACUMOS_SETUP_PREREQS=true

# External component options
export ACUMOS_DEPLOY_MARIADB=true
export ACUMOS_SETUP_DB=true
export ACUMOS_DEPLOY_DOCKER=true
export ACUMOS_DEPLOY_NEXUS=true
export ACUMOS_DEPLOY_KONG=true
export ACUMOS_DEPLOY_ELK=false
export ACUMOS_MARIADB_VERSION=10.2
export ACUMOS_MARIADB_HOST=$ACUMOS_DOMAIN
export ACUMOS_MARIADB_PORT=30001
export ACUMOS_MARIADB_ADMINER_PORT=30380
export ACUMOS_MARIADB_USER=acumos_opr
export ACUMOS_MARIADB_PASSWORD=
export ACUMOS_MARIADB_USER_PASSWORD=
export ACUMOS_DOCKER_API_HOST=$ACUMOS_DOMAIN
export ACUMOS_DOCKER_API_PORT=2375
export ACUMOS_NEXUS_ADMIN_PASSWORD=admin123
export ACUMOS_NEXUS_ADMIN_USERNAME=admin
export ACUMOS_NEXUS_API_PORT=30881
export ACUMOS_NEXUS_HOST=$ACUMOS_DOMAIN
export ACUMOS_NEXUS_RO_USER=acumos_ro
export ACUMOS_NEXUS_RO_USER_PASSWORD=
export ACUMOS_NEXUS_RW_USER=acumos_rw
export ACUMOS_NEXUS_RW_USER_PASSWORD=
export ACUMOS_DOCKER_REGISTRY_USER=$ACUMOS_NEXUS_RW_USER
export ACUMOS_DOCKER_REGISTRY_PASSWORD=
export ACUMOS_NEXUS_MAVEN_REPO_PATH=repository
export ACUMOS_NEXUS_MAVEN_REPO=acumos_model_maven
export ACUMOS_NEXUS_DOCKER_REPO=docker_model_maven
export ACUMOS_DOCKER_REGISTRY_HOST=$ACUMOS_NEXUS_HOST
export ACUMOS_DOCKER_MODEL_PORT=30882
export ACUMOS_DOCKER_IMAGETAG_PREFIX=nexus:$ACUMOS_DOCKER_MODEL_PORT
export ACUMOS_KONG_ADMIN_HOST=$ACUMOS_DOMAIN
export ACUMOS_KONG_ADMIN_PORT=30081
export ACUMOS_KONG_ADMIN_SSL_PORT=30444
export ACUMOS_KONG_DB_PORT=30532
export ACUMOS_KONG_PROXY_PORT=30080
export ACUMOS_KONG_PROXY_SSL_PORT=30443
export ACUMOS_ELK_DOMAIN=$ACUMOS_DOMAIN
export ACUMOS_ELK_HOST=$ACUMOS_HOST
export ACUMOS_ELK_KIBANA_PORT=30561
export HTTP_PROXY=""
export HTTPS_PROXY=""

# Component options
export ACUMOS_ADMIN_EMAIL='acumos@example.com'
export ACUMOS_AZURE_CLIENT_PORT=9081
export ACUMOS_CDS_PREVIOUS_VERSION=
export ACUMOS_CDS_VERSION=1.18
export ACUMOS_CDS_DB='acumos_cds'
export ACUMOS_CDS_HOST=$ACUMOS_DOMAIN
export ACUMOS_CDS_PORT=30800
export ACUMOS_CDS_USER=ccds_client
export ACUMOS_CDS_PASSWORD=
export ACUMOS_CMS_HOST=$ACUMOS_DOMAIN
export ACUMOS_CMS_PORT=30980
export ACUMOS_CMS_DB='acumos_cms'
export ACUMOS_DOCKER_PROXY_HOST=$ACUMOS_DOMAIN
export ACUMOS_DOCKER_PROXY_PORT=30883
export ACUMOS_DOCKER_PROXY_USERNAME=
export ACUMOS_DOCKER_PROXY_PASSWORD=
export ACUMOS_DSCE_PORT=8088
export ACUMOS_FEDERATION_HOST=$ACUMOS_DOMAIN
export ACUMOS_FEDERATION_LOCAL_PORT=30985
export ACUMOS_FEDERATION_PORT=30984
export ACUMOS_CERT_PREFIX=acumos
export ACUMOS_CA_CERT=${ACUMOS_CERT_PREFIX}-ca.crt
export ACUMOS_CERT=${ACUMOS_CERT_PREFIX}.crt
export ACUMOS_CERT_KEY=${ACUMOS_CERT_PREFIX}.key
export ACUMOS_CERT_KEY_PASSWORD=
export ACUMOS_KEYSTORE=${ACUMOS_CERT_PREFIX}-keystore.p12
export ACUMOS_KEYSTORE_PASSWORD=
export ACUMOS_TRUSTSTORE=${ACUMOS_CERT_PREFIX}-truststore.jks
export ACUMOS_KUBERNETES_CLIENT_PORT=8082
export ACUMOS_MICROSERVICE_GENERATION_PORT=8336
export ACUMOS_ONBOARDING_PORT=8090
export ACUMOS_ONBOARDING_TOKENMODE=jwtToken
export ACUMOS_ONBOARDING_CLIPUSHURL="https://${ACUMOS_DOMAIN}:${ACUMOS_KONG_PROXY_SSL_PORT}/onboarding-app/v2/models"
export ACUMOS_ONBOARDING_CLIAUTHURL="https://${ACUMOS_DOMAIN}:${ACUMOS_KONG_PROXY_SSL_PORT}/onboarding-app/v2/auth"
export ACUMOS_OPERATOR_ID=acumos-aio
export ACUMOS_PORTAL_BE_PORT=8083
export ACUMOS_PORTAL_FE_PORT=8085
export ACUMOS_PROBE_PORT=5006
export ACUMOS_VALIDATION_CLIENT_PORT=9603
export ACUMOS_VALIDATION_ENGINE_PORT=9605
export ACUMOS_VALIDATION_MIDDLEWARE_PORT=9604
export PYTHON_EXTRAINDEX=
export PYTHON_EXTRAINDEX_HOST=

# Options applied when kong is not deployed (ACUMOS_DEPLOY_KONG != true)
export ACUMOS_ONBOARDING_NODEPORT=30890
export ACUMOS_PORTAL_FE_NODEPORT=30885

# Acumos model deployment options
export ACUMOS_DATA_BROKER_INTERNAL_PORT=8080
export ACUMOS_DATA_BROKER_PORT=8556
export ACUMOS_DEPLOYED_SOLUTION_PORT=3330
export ACUMOS_DEPLOYED_VM_PASSWORD='12NewPA$$w0rd!'
export ACUMOS_DEPLOYED_VM_USER=dockerUser
export ACUMOS_PROBE_PORT=5006

# Kubernetes options
# Select "tenant" below to skip creation of hostPath PVs
export ACUMOS_K8S_ROLE=admin
export ACUMOS_NAMESPACE=acumos
export ACUMOS_HOST_USER=

# Persistent Volume options
export ACUMOS_CERTS_PV_NAME="pv-$ACUMOS_NAMESPACE-certs"
export ACUMOS_CERTS_PV_SIZE=10Mi
export ACUMOS_LOGS_PV_NAME="pv-$ACUMOS_NAMESPACE-logs"
export ACUMOS_LOGS_PV_SIZE=1Gi
export DOCKER_VOLUME_PV_NAME="pv-$ACUMOS_NAMESPACE-docker-volume"
export DOCKER_VOLUME_PV_SIZE=5Gi
export KONG_DB_PV_NAME="pv-$ACUMOS_NAMESPACE-kong-db"
export KONG_DB_PV_SIZE=10Mi
export MARIADB_DATA_PV_NAME="pv-$ACUMOS_NAMESPACE-mariadb-data"
export MARIADB_DATA_PV_SIZE=5Gi
export NEXUS_DATA_PV_NAME="pv-$ACUMOS_NAMESPACE-nexus-data"
export NEXUS_DATA_PV_SIZE=10Gi
