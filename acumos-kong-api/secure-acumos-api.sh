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
# What this is: File for Acumos Kong API certificates installation.
# Usage:
# - Intended to be add api into Acumos Kong API.
#
# Be verbose
set -x

# Registries
export ACUMOS_KONG_API_HOST_NAME=localhost
export ACUMOS_KONG_API_PORT=7001
export ACUMOS_KONG_CERTIFICATE_PATH=./certs
export ACUMOS_CRT=localhost.csr
export ACUMOS_KEY=localhost.key
export ACUMOS_HOST_NAME=cognita-dev1-vm01-core
export ACUMOS_HOME_PAGE_PORT=8085
export ACUMOS_ONBOARDING_PORT=8090

echo "Installing certificate.\n"

#install-certifate
curl -i -X POST http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/certificates \
    -F "cert=@${ACUMOS_KONG_CERTIFICATE_PATH}/${ACUMOS_CRT}" \
    -F "key=@${ACUMOS_KONG_CERTIFICATE_PATH}/${ACUMOS_KEY}" \
    -F "snis=${ACUMOS_KONG_API_HOST_NAME}"

echo "\n\nAdding API to admin port.\n"

#create-root-api
curl -i -X POST \
  --url http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/apis/ \
  --data "https_only=true" \
  --data "name=root" \
  --data "upstream_url=http://${ACUMOS_HOST_NAME}:${ACUMOS_HOME_PAGE_PORT}" \
  --data "uris=/"

#create-onboarding-local-api
curl -i -X POST \
  --url http://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}/apis/ \
  --data "name=onboarding-app" \
  --data "upstream_url=http://${ACUMOS_HOST_NAME}:${ACUMOS_ONBOARDING_PORT}/onboarding-app" \
  --data "uris=/onboarding-app"

echo "\nAPI added successfully.\n\n"