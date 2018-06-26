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

# Registry

export NEXUS3_RELEASE_REGISTRY_LF=nexus3.acumos.org:10002


#Ports
export ACUMOS_MARIADB_PORT=3306
export ACUMOS_MARIADB_ROOT_PASSWORD=XXXXX
export ACUMOS_PORTAL_FE_PORT=8085
export ACUMOS_CMS_PORT=9080
export ACUMOS_PORTAL_BE_PORT=8083
export ACUMOS_PORTAL_DS_COMPOSITION_PORT=8088
export ACUMOS_COMMON_DATA_SVC_PORT=8000
export ACUMOS_ONBOARDING_APP_PORT=8090
export ACUMOS_FEDERATION_GATEWAY_PORT=9084
export ACUMOS_PLATON_PORT=9083
export ACUMOS_AZURE_CLIENT_PORT=9081
export ACUMOS_KONG_POSTGRES_PORT=5432
export ACUMOS_KONG_ADMIN_PORT=8001
export ACUMOS_KONG_PROXY_PORT=8000
export ACUMOS_KONG_SSL_PORT=8443
export ACUMOS_KONG_ADM_SSL_PORT=8444
export ACUMOS_NEXUS_PORT=8001
export ACUMOS_NEXUS_ENDPOINT_PORT=8081
export ACUMOS_PROXY_PORT=3128
export ACUMOS_DOCKER_PORT=2375


# Images
export ACUMOS_ONBOARDING_IMAGE=onboarding-app:1.26.0
export ACUMOS_PORTAL_BE_IMAGE=acumos-portal-be:1.15.26
export ACUMOS_PORTAL_FE_IMAGE=acumos-portal-fe:1.15.26
export ACUMOS_CMS_IMAGE=acumos-cms-docker:1.3.4
export ACUMOS_DESIGN_STUDIO_IMAGE=ds-compositionengine:0.0.30
export ACUMOS_DATA_BROKER_IMAGE=databroker-zipbroker:0.0.1
export ACUMOS_CSV_DATA_BROKER_IMAGE=csvdatabroker:0.0.1
export ACUMOS_CDS_IMAGE=common-dataservice:1.14.3
export ACUMOS_FEDERATION_IMAGE=federation-gateway:1.1.3

#Nexus
export ACUMOS_DOCKER_HOST=acumos-docker-service
export ACUMOS_NEXUS_SERVICE=acumos-nexus-service
export ACUMOS_NEXUS_USERNAME=acumos-k8-user-rw
export ACUMOS_NEXUS_PASSWORD=xxxxxxx
export ACUMOS_PROXY=acumos-proxy

#Kong and Database
export ACUMOS_CDS_DB=CDS
export ACUMOS_CDS_USER=ccds_client
export ACUMOS_CDS_PASSWORD=xxxxxx
export ACUMOS_MARIADB_USER=CDS_USER
export ACUMOS_MARIADB_PASSWORD=xxxxx
export ACUMOS_CMS_DB=acumos_CMS
export ACUMOS_CMS_USER=CMS_USER
export ACUMOS_CMS_PASSWORD=xxxxxxx
export ACUMOS_KONG_POSTGRES_USER=kong
export ACUMOS_KONG_POSTGRES_PASSWORD=xxxx
export ACUMOS_KONG_POSTGRES_DB=kong
export ACUMOS_KONG_PG_PASSWORD=xxxx

#Namespace and PVC
export ACUMOS_NAMESPACE=acumos-ns01
export ACUMOS_MARIADB_PVC_STORAGE=1Gi
export ACUMOS_PVC_STORAGE=1Gi
export ACUMOS_NEXUS_PVC_STORAGE=5Gi


#1: Env file 
#2: YAML File
#3: create/delete
source $1 && envsubst < $2 | kubectl $3 -f - 
