#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2019 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
# What this is: Environment file for ELK stack depoyment for Acumos.
# Prerequisites:
# - Ubuntu Xenial or Centos 7 server
# Usage:
# - Intended to be called from deploy-elk.sh and other scripts in this repo
# - Customize the values here for your needs.
#

export ACUMOS_ELK_NAMESPACE=$ACUMOS_NAMESPACE
export ACUMOS_ELK_DOMAIN=$(hostname)
# Hard-code ACUMOS_ELK_HOST below to the primary IP address (as primary route) of
# your ELK host server, if the generated value does not work for your server
# (there have been reports that this command does not always work)
host=$(/sbin/ip route get 8.8.8.8 | head -1 | sed 's/^.*src //' | awk '{print $1}')
export ACUMOS_ELK_HOST=$host

# External component options
export HTTP_PROXY=""
export HTTPS_PROXY=""

# Component options
export ACUMOS_DEPLOY_METRICBEAT=true
export ACUMOS_CDS_DB="acumos_cds"
export ACUMOS_ELK_ELASTICSEARCH_PORT=30930
export ACUMOS_ELK_ELASTICSEARCH_INDEX_PORT=30920
export ACUMOS_ELK_LOGSTASH_PORT=30500
export ACUMOS_ELK_KIBANA_PORT=30561
export ACUMOS_ELK_ES_JAVA_HEAP_MIN_SIZE=1g
export ACUMOS_ELK_ES_JAVA_HEAP_MAX_SIZE=2g
export ACUMOS_ELK_LS_JAVA_HEAP_MIN_SIZE=1g
export ACUMOS_ELK_LS_JAVA_HEAP_MAX_SIZE=2g
export ACUMOS_MARIADB_HOST=
export ACUMOS_MARIADB_PORT=30306

# Persistent Volume options
export ELASTICSEARCH_DATA_PV_NAME="pv-$ACUMOS_ELK_NAMESPACE-elasticsearch-data"
export ACUMOS_ELASTICSEARCH_DATA_PV_SIZE=1Gi
