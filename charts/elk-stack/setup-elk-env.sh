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
# What this is: Script to set environment file for ELK stack depoyment for Acumos.
# Prerequisites:
# - Ubuntu Xenial or Centos 7 server
# Usage:
# - Intended to be called from deploy-elk.sh and other scripts in this repo
# - Customize the values here for your needs.
# - defaults are set by "${parameter}:-default}"

if [[ -e elk-env.sh ]]; then source elk-env.sh; fi

export ACUMOS_ELK_NAMESPACE="${ACUMOS_ELK_NAMESPACE:-acumos-elk}"

# External component options
export HTTP_PROXY="${HTTP_PROXY:-}"
export HTTPS_PROXY="${HTTPS_PROXY:-}"

# Set by setup-elk.sh
export DEPLOY_RESULT=
export FAIL_REASON=

# Component options
export ACUMOS_DEPLOY_METRICBEAT="${ACUMOS_DEPLOY_METRICBEAT:-true}"
export ACUMOS_CDS_DB="${ACUMOS_CDS_DB:-acumos_cds}"
export ACUMOS_ELK_ELASTICSEARCH_PORT="${ACUMOS_ELK_ELASTICSEARCH_PORT:-30930}"
export ACUMOS_ELK_ELASTICSEARCH_INDEX_PORT="${ACUMOS_ELK_ELASTICSEARCH_INDEX_PORT:-30920}"
export ACUMOS_ELK_LOGSTASH_PORT="${ACUMOS_ELK_LOGSTASH_PORT:-30500}"
export ACUMOS_ELK_KIBANA_PORT="${ACUMOS_ELK_KIBANA_PORT:-30561}"
export ACUMOS_ELK_ES_JAVA_HEAP_MIN_SIZE="${ACUMOS_ELK_ES_JAVA_HEAP_MIN_SIZE:-1g}"
export ACUMOS_ELK_ES_JAVA_HEAP_MAX_SIZE="${ACUMOS_ELK_ES_JAVA_HEAP_MAX_SIZE:-2g}"
export ACUMOS_ELK_LS_JAVA_HEAP_MIN_SIZE="${ACUMOS_ELK_LS_JAVA_HEAP_MIN_SIZE:-1g}"
export ACUMOS_ELK_LS_JAVA_HEAP_MAX_SIZE="${ACUMOS_ELK_LS_JAVA_HEAP_MAX_SIZE:-2g}"

# Persistent Volume options
export ELASTICSEARCH_DATA_PVC_NAME="${ELASTICSEARCH_DATA_PVC_NAME:-elasticsearch-data}"
export ACUMOS_ELASTICSEARCH_DATA_PV_SIZE="${ACUMOS_ELASTICSEARCH_DATA_PV_SIZE:-1Gi}"

cat <<EOF >elk-env.sh
export ACUMOS_ELK_NAMESPACE=$ACUMOS_ELK_NAMESPACE
export HTTP_PROXY=$HTTP_PROXY
export HTTPS_PROXY=$HTTPS_PROXY
export ACUMOS_DEPLOY_METRICBEAT=$ACUMOS_DEPLOY_METRICBEAT
export ACUMOS_CDS_DB=$ACUMOS_CDS_DB
export ACUMOS_ELK_ELASTICSEARCH_PORT=$ACUMOS_ELK_ELASTICSEARCH_PORT
export ACUMOS_ELK_ELASTICSEARCH_INDEX_PORT=$ACUMOS_ELK_ELASTICSEARCH_INDEX_PORT
export ACUMOS_ELK_LOGSTASH_PORT=$ACUMOS_ELK_LOGSTASH_PORT
export ACUMOS_ELK_KIBANA_PORT=$ACUMOS_ELK_KIBANA_PORT
export ACUMOS_ELK_ES_JAVA_HEAP_MIN_SIZE=$ACUMOS_ELK_ES_JAVA_HEAP_MIN_SIZE
export ACUMOS_ELK_ES_JAVA_HEAP_MAX_SIZE=$ACUMOS_ELK_ES_JAVA_HEAP_MAX_SIZE
export ACUMOS_ELK_LS_JAVA_HEAP_MIN_SIZE=$ACUMOS_ELK_LS_JAVA_HEAP_MIN_SIZE
export ACUMOS_ELK_LS_JAVA_HEAP_MAX_SIZE=$ACUMOS_ELK_LS_JAVA_HEAP_MAX_SIZE
EOF
