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
# What this is: Environment file for Acumos Kong API installation.
# Usage:
# - Intended to be called from docker-compose.yml
#

# Be verbose
set -x

export ACUMOS_KONG_API_DATABASE_CONTAINER_NAME=acumos-kong-database
export ACUMOS_KONG_API_POSTGRES_USER=kong
export ACUMOS_KONG_API_DATABASE=postgres

export ACUMOS_KONG_API_DATABASE_PORT=5433
export ACUMOS_KONG_API_LISTENS_HTTP_TRAFFIC_PORT=7000
export ACUMOS_KONG_API_LISTENS_HTTPS_TRAFFIC_PORT=443
export ACUMOS_KONG_API_LISTENS_HTTP_ADMIN_API_PORT=7001
export ACUMOS_KONG_API_LISTENS_HTTPS_ADMIN_API_PORT=7004

# Images
export ACUMOS_KONG_API_POSTGRES_DATABASE_IMAGE=postgres:9.4
export ACUMOS_KONG_API_IMAGE=kong:0.11.0


