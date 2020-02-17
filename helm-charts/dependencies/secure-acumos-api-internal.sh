#! /bin/bash
# Be verbose
# set -x

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

# Registries
#export ACUMOS_KONG_API_HOST_NAME=acumos-kong-proxy.acumos-ns01
export ACUMOS_KONG_API_HOST_NAME=acumosk8s-test.westus.cloudapp.azure.com
export ACUMOS_KONG_API_HOST_SNIS=acumosk8s-test.westus.cloudapp.azure.com
export ACUMOS_KONG_API_PORT=8001
export ACUMOS_KONG_CERTIFICATE_PATH=/home/cognitamaster/acumos-k8s/certs/test
export ACUMOS_CRT=server.crt
export ACUMOS_KEY=server.key
export ACUMOS_HOST_NAME=acumos.acumos-test
export ACUMOS_NEXUS_HOST_NAME=acumos-nexus-service.acumos-test
export ACUMOS_HOME_PAGE_PORT=8085
export ACUMOS_ONBOARDING_PORT=8090
export ACUMOS_CMS_PORT=9080
export ACUMOS_NEXUS_PORT=8001

echo "Installing certificate.\n"

#install-certificates
curl -i -X POST http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/certificates \
    -F "cert=@${ACUMOS_KONG_CERTIFICATE_PATH}/${ACUMOS_CRT}" \
    -F "key=@${ACUMOS_KONG_CERTIFICATE_PATH}/${ACUMOS_KEY}" \
    -F "snis=${ACUMOS_KONG_API_HOST_SNIS}"

echo "\n\nAdding API to admin port.\n"

#create-root-api
curl -i -X POST \
  --url http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/apis/ \
  --data "https_only=true" \
  --data "name=root" \
  --data "upstream_url=http://${ACUMOS_HOST_NAME}:${ACUMOS_HOME_PAGE_PORT}" \
  --data "hosts=${ACUMOS_KONG_API_HOST_SNIS}" \
  --data "uris=/"

#Enable Bot-Detect-root-api
curl -X POST http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/apis/root/plugins \
    --data "name=bot-detection"

#Enable Rate-Limit-root-api
curl -X POST http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/apis/root/plugins \
    --data "name=rate-limiting"  \
    --data "config.second=150" \
    --data "config.hour=10000"

#create-onboarding-local-api
curl -i -X POST \
  --url http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/apis/ \
  --data "https_only=true" \
  --data "name=onboarding-app" \
  --data "upstream_url=http://${ACUMOS_HOST_NAME}:${ACUMOS_ONBOARDING_PORT}/onboarding-app" \
  --data "hosts=${ACUMOS_KONG_API_HOST_SNIS}" \
  --data "upstream_read_timeout=28800000" \
  --data "upstream_send_timeout=28800000" \
  --data "uris=/onboarding-app"

#Enable Bot-Detect-onboarding-app-api
curl -X POST http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/apis/onboarding-app/plugins \
    --data "name=bot-detection"
#Enable Rate-Limit-onboarding-app-api
curl -X POST http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/apis/onboarding-app/plugins \
    --data "name=rate-limiting"  \
    --data "config.second=50" \
    --data "config.hour=1000"

#create-CMS-api
curl -i -X POST \
--url http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/apis/ \
  --data "https_only=true" \
  --data "name=cms" \
  --data "upstream_url=http://${ACUMOS_HOST_NAME}:${ACUMOS_CMS_PORT}/cms" \
  --data "hosts=${ACUMOS_KONG_API_HOST_SNIS}" \
  --data "uris=/cms"
#Enable Bot-Detect-cms-api
curl -X POST http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/apis/cms/plugins \
    --data "name=bot-detection"
#Enable Rate-Limit-cms-app-api
curl -X POST http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/apis/cms/plugins \
    --data "name=rate-limiting"  \
    --data "config.second=100" \
    --data "config.hour=10000"
echo "\nAPI added successfully.\n\n"
