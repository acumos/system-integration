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
export ACUMOS_AIO_VERSION=2.4

# Acumos project Registries
export ACUMOS_PROJECT_NEXUS_USERNAME=docker
export ACUMOS_PROJECT_NEXUS_PASSWORD=docker
# Should NOT need to use Snapshot
export ACUMOS_SNAPSHOT=nexus3.acumos.org:10003
# Should ONLY use Staging, if Release version not available or compatible
export ACUMOS_STAGING=nexus3.acumos.org:10004
# Should ONLY use Release version
export ACUMOS_RELEASE=nexus3.acumos.org:10002

# Images based upon Boreas release assembly
# https://wiki.acumos.org/display/REL/Weekly+Assembly+Acumos_Boreas_Release
# Core components
export ACUMOS_DELETE_SNAPSHOTS=false
export AZURE_CLIENT_IMAGE=$ACUMOS_RELEASE/acumos-azure-client:2.0.15
export PORTAL_BE_IMAGE=$ACUMOS_RELEASE/acumos-portal-be:2.2.23
export PORTAL_FE_IMAGE=$ACUMOS_RELEASE/acumos-portal-fe:2.2.23
export COMMON_DATASERVICE_IMAGE=$ACUMOS_RELEASE/common-dataservice:2.2.5
export DESIGNSTUDIO_IMAGE=$ACUMOS_RELEASE/ds-compositionengine:2.1.0
export FEDERATION_IMAGE=$ACUMOS_RELEASE/federation-gateway:2.2.1
export KUBERNETES_CLIENT_IMAGE=$ACUMOS_RELEASE/kubernetes-client:2.0.11
export MICROSERVICE_GENERATION_IMAGE=$ACUMOS_SNAPSHOT/microservice-generation:2.14.1-SNAPSHOT
export ONBOARDING_IMAGE=$ACUMOS_RELEASE/onboarding-app:2.16.0
export SECURITY_VERIFICATION_IMAGE=$ACUMOS_RELEASE/security-verification:0.0.24
export OPENSTACK_CLIENT_IMAGE=$ACUMOS_RELEASE/openstack-client:2.0.12

# Model-execution-components
export DATABROKER_SQLBROKER_IMAGE=$ACUMOS_RELEASE/sqldatabroker:1.2.0
export DATABROKER_CSVBROKER_IMAGE=$ACUMOS_RELEASE/csvdatabroker:1.4.0
export ONBOARDING_BASE_IMAGE=$ACUMOS_RELEASE/onboarding-base-r:1.0.0
export BLUEPRINT_ORCHESTRATOR_IMAGE=$ACUMOS_RELEASE/blueprint-orchestrator:2.0.13
export H2O_GENERICJAVA_MODELRUNNER_IMAGE=$ACUMOS_RELEASE/h2o-genericjava-modelrunner:2.2.3
export DATABROKER_ZIPBROKER_IMAGE=$ACUMOS_RELEASE/databroker-zipbroker:0.0.1
export PROTO_VIEWER_IMAGE=$ACUMOS_RELEASE/acumos-proto-viewer:1.5.7

# Set by setup_prereqs.sh or oneclick_deploy.sh
export DEPLOYED_UNDER=
export K8S_DIST=
export AIO_ROOT=
export ACUMOS_DOMAIN=
export ACUMOS_PORT=443
export ACUMOS_ORIGIN=
export ACUMOS_DOMAIN_IP=
export ACUMOS_HOST=
export ACUMOS_HOST_IP=
export ACUMOS_HOST_OS=
export ACUMOS_HOST_OS_VER=
export ACUMOS_ADMIN_REGISTRY_USER=
export ACUMOS_ADMIN_REGISTRY_PASSWORD=
export DEPLOY_RESULT=
export FAIL_REASON=

# External component options
export ACUMOS_DEPLOY_MARIADB=true
export ACUMOS_SETUP_DB=true
export ACUMOS_DEPLOY_DOCKER=true
export ACUMOS_DEPLOY_DOCKER_DIND=true
export ACUMOS_DEPLOY_NEXUS=true
export ACUMOS_DEPLOY_ELK=true
export ACUMOS_DEPLOY_ELK_METRICBEAT=true
export ACUMOS_DEPLOY_ELK_FILEBEAT=true
export ACUMOS_DEPLOY_MLWB=true
export ACUMOS_DEPLOY_INGRESS=true
export ACUMOS_DOCKER_API_HOST=docker-dind-service
export ACUMOS_DOCKER_API_PORT=2375
export ACUMOS_NEXUS_ADMIN_PASSWORD=admin123
export ACUMOS_NEXUS_ADMIN_USERNAME=admin
export ACUMOS_NEXUS_API_PORT=30881
export ACUMOS_NEXUS_GROUP=org.acumos
export ACUMOS_NEXUS_DOMAIN=$ACUMOS_DOMAIN
export ACUMOS_NEXUS_HOST=$ACUMOS_HOST
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
export ACUMOS_KONG_PROXY_SSL_PORT=443
export ACUMOS_INGRESS_SERVICE=nginx
export ACUMOS_INGRESS_HTTP_PORT=30080
export ACUMOS_INGRESS_HTTPS_PORT=30443
export ACUMOS_INGRESS_MAX_REQUEST_SIZE=1000m
export ACUMOS_INGRESS_MAX_REQUEST_SIZE=1000m
export ACUMOS_HTTP_PROXY=
export ACUMOS_HTTPS_PROXY=

# Component options
export ACUMOS_PRIVILEGED_ENABLE=false
export ACUMOS_CAS_ENABLE=false
export ACUMOS_VERIFY_ACCOUNT=false
export ACUMOS_TOKEN_EXP_TIME=24
export ACUMOS_ADMIN=admin
export ACUMOS_EMAIL_SERVICE=none
export ACUMOS_SPRING_MAIL_SERVICE_DOMAIN=
export ACUMOS_SPRING_MAIL_SERVICE_PORT=25
export ACUMOS_SPRING_MAIL_USERNAME=
export ACUMOS_SPRING_MAIL_PASSWORD=
export ACUMOS_SPRING_MAIL_STARTTLS=true
export ACUMOS_SPRING_MAIL_AUTH=true
export ACUMOS_SPRING_MAIL_PROTOCOL=
export ACUMOS_MAILJET_API_KEY=
export ACUMOS_MAILJET_SECRET_KEY=
export ACUMOS_MAILJET_ADMIN_EMAIL=
export ACUMOS_ADMIN_EMAIL=acumos@example.com
export ACUMOS_CDS_PREVIOUS_VERSION=
export ACUMOS_CDS_HOST=cds-service
export ACUMOS_CDS_PORT=8000
export ACUMOS_CDS_VERSION=2.2
export ACUMOS_CDS_DB='acumos_cds'
export ACUMOS_CDS_USER=ccds_client
export ACUMOS_CDS_PASSWORD=
export ACUMOS_JWT_KEY=
export ACUMOS_DOCKER_PROXY_HOST=$ACUMOS_DOMAIN
export ACUMOS_DOCKER_PROXY_PORT=30883
export ACUMOS_DOCKER_PROXY_USERNAME=
export ACUMOS_DOCKER_PROXY_PASSWORD=
export ACUMOS_FEDERATION_HOST=$ACUMOS_DOMAIN
export ACUMOS_FEDERATION_LOCAL_PORT=9011
export ACUMOS_FEDERATION_PORT=30984
export ACUMOS_ONBOARDING_TOKENMODE=jwtToken
export ACUMOS_ONBOARDING_API_TIMEOUT=600
export ACUMOS_ONBOARDING_CLIPUSHURL="https://${ACUMOS_ORIGIN}/onboarding-app/v2/models"
export ACUMOS_ONBOARDING_CLIAUTHURL="https://${ACUMOS_ORIGIN}/onboarding-app/v2/auth"
export ACUMOS_MICROSERVICE_GENERATION_ASYNC=false
export ACUMOS_OPERATOR_ID=12345678-abcd-90ab-cdef-1234567890ab
export ACUMOS_PORTAL_PUBLISH_SELF_REQUEST_ENABLED=true
export ACUMOS_PORTAL_ENABLE_PUBLICATION=true
export ACUMOS_PORTAL_DOCUMENT_MAX_SIZE=100000000
export ACUMOS_PORTAL_IMAGE_MAX_SIZE=1000KB
export ACUMOS_ENABLE_SECURITY_VERIFICATION=true
export ACUMOS_SECURITY_VERIFICATION_PORT=9082
export ACUMOS_SUCCESS_WAIT_TIME=300
export PYTHON_EXTRAINDEX=
export PYTHON_EXTRAINDEX_HOST=

# Core platform certificate options
export ACUMOS_CREATE_CERTS=true
export ACUMOS_CERT_PREFIX=acumos
export ACUMOS_CERT_SUBJECT_NAME=$ACUMOS_DOMAIN
export ACUMOS_CA_CERT=${ACUMOS_CERT_PREFIX}-ca.crt
export ACUMOS_CERT=${ACUMOS_CERT_PREFIX}.crt
export ACUMOS_CERT_KEY=${ACUMOS_CERT_PREFIX}.key
export ACUMOS_CERT_KEY_PASSWORD=
export ACUMOS_KEYSTORE_P12=${ACUMOS_CERT_PREFIX}-keystore.p12
export ACUMOS_KEYSTORE_JKS=${ACUMOS_CERT_PREFIX}-keystore.jks
export ACUMOS_KEYSTORE_PASSWORD=
export ACUMOS_TRUSTSTORE=${ACUMOS_CERT_PREFIX}-truststore.jks
export ACUMOS_TRUSTSTORE_PASSWORD=
if [[ -e $AIO_ROOT/certs/cert_env.sh ]]; then source $AIO_ROOT/certs/cert_env.sh; fi

# Acumos model deployment options
export ACUMOS_DATA_BROKER_INTERNAL_PORT=8080
export ACUMOS_DATA_BROKER_PORT=8556
export ACUMOS_DEPLOYED_SOLUTION_PORT=3330
export ACUMOS_DEPLOYED_VM_PASSWORD='12NewPA$$w0rd!'
export ACUMOS_DEPLOYED_VM_USER=dockerUser
export ACUMOS_PROBE_PORT=5006

# Kubernetes options
export ACUMOS_K8S_ADMIN_SCOPE=namespace
export ACUMOS_K8S_DEPLOYMENT_VERSION="apps/v1"
export ACUMOS_NAMESPACE=acumos
export ACUMOS_HOST_USER=

# Persistent Volume options
export ACUMOS_CREATE_PVS=true
export ACUMOS_PVC_TO_PV_BINDING=true
export ACUMOS_CERTS_PV_NAME="certs"
export ACUMOS_CERTS_PV_SIZE=10Mi
export ACUMOS_LOGS_PVC_NAME="logs"
export ACUMOS_LOGS_PV_NAME="logs"
export ACUMOS_LOGS_PV_SIZE=1Gi
export DOCKER_VOLUME_PVC_NAME="docker-volume"
export DOCKER_VOLUME_PV_NAME="docker-volume"
export DOCKER_VOLUME_PV_SIZE=5Gi
export NEXUS_DATA_PVC_NAME="nexus-data"
export NEXUS_DATA_PV_NAME="nexus-data"
export NEXUS_DATA_PV_SIZE=10Gi
export KONG_DB_PVC_NAME="kong-data"
export KONG_DB_PV_NAME="kong-data"
export KONG_DB_PV_SIZE=1Gi
export ACUMOS_1GI_STORAGECLASSNAME=
export ACUMOS_5GI_STORAGECLASSNAME=
export ACUMOS_10GI_STORAGECLASSNAME=

# Supplemental component options
if [[ -e $AIO_ROOT/mariadb_env.sh ]]; then source $AIO_ROOT/mariadb_env.sh; fi
if [[ -e $AIO_ROOT/elk_env.sh ]]; then source $AIO_ROOT/elk_env.sh; fi
