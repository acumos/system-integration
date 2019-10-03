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
# What this is: Script to set environment file for nexus installation.
# Prerequisites:
# - Ubuntu Xenial or Centos 7 server
# Usage:
# - Intended to be called from oneclick_deploy.sh and other scripts in this repo
#

if [[ -e nexus_env.sh ]]; then source nexus_env.sh; fi

export ACUMOS_NEXUS_HOST="${ACUMOS_NEXUS_HOST:-$ACUMOS_HOST}"
export ACUMOS_DOCKER_REGISTRY_HOST=$ACUMOS_NEXUS_HOST

export ACUMOS_NEXUS_NAMESPACE="${ACUMOS_NEXUS_NAMESPACE:-acumos-nexus}"
export ACUMOS_NEXUS_ADMIN_PASSWORD="${ACUMOS_NEXUS_ADMIN_PASSWORD:-admin123}"
export ACUMOS_NEXUS_ADMIN_USERNAME="${ACUMOS_NEXUS_ADMIN_USERNAME:-admin}"
export ACUMOS_NEXUS_API_PORT="${ACUMOS_NEXUS_API_PORT:-30881}"
export ACUMOS_NEXUS_GROUP="${ACUMOS_NEXUS_GROUP:-org.acumos}"
export ACUMOS_NEXUS_RO_USER="${ACUMOS_NEXUS_RO_USER:-acumos_ro}"
export ACUMOS_NEXUS_RO_USER_PASSWORD="${ACUMOS_NEXUS_RO_USER_PASSWORD:-}"
export ACUMOS_NEXUS_RW_USER="${ACUMOS_NEXUS_RW_USER:-acumos_rw}"
export ACUMOS_NEXUS_RW_USER_PASSWORD="${ACUMOS_NEXUS_RW_USER_PASSWORD:-}"
export ACUMOS_DOCKER_REGISTRY_USER="${ACUMOS_DOCKER_REGISTRY_USER:-$ACUMOS_NEXUS_RW_USER}"
export ACUMOS_DOCKER_REGISTRY_PASSWORD="${ACUMOS_DOCKER_REGISTRY_PASSWORD:-$ACUMOS_NEXUS_RW_USER_PASSWORD}"
export ACUMOS_NEXUS_MAVEN_REPO_PATH="${ACUMOS_NEXUS_MAVEN_REPO_PATH:-repository}"
export ACUMOS_NEXUS_MAVEN_REPO="${ACUMOS_NEXUS_MAVEN_REPO:-acumos_model_maven}"
export ACUMOS_NEXUS_DOCKER_REPO="${ACUMOS_NEXUS_DOCKER_REPO:-docker_model_maven}"
export ACUMOS_DOCKER_MODEL_PORT="${ACUMOS_DOCKER_MODEL_PORT:-30882}"
export ACUMOS_DOCKER_IMAGETAG_PREFIX="${ACUMOS_DOCKER_IMAGETAG_PREFIX:-}"
export NEXUS_DATA_PVC_NAME="${NEXUS_DATA_PVC_NAME:-nexus-data}"
export NEXUS_DATA_PV_NAME="${NEXUS_DATA_PV_NAME:-nexus-data}"
export NEXUS_DATA_PV_SIZE="${NEXUS_DATA_PV_SIZE:-10Gi}"

cat <<EOF >nexus_env.sh
export ACUMOS_NEXUS_HOST=$ACUMOS_NEXUS_HOST
export ACUMOS_DOCKER_REGISTRY_HOST=$ACUMOS_DOCKER_REGISTRY_HOST
export ACUMOS_NEXUS_ADMIN_PASSWORD=$ACUMOS_NEXUS_ADMIN_PASSWORD
export ACUMOS_NEXUS_ADMIN_USERNAME=$ACUMOS_NEXUS_ADMIN_USERNAME
export ACUMOS_NEXUS_API_PORT=$ACUMOS_NEXUS_API_PORT
export ACUMOS_NEXUS_GROUP=$ACUMOS_NEXUS_GROUP
export ACUMOS_NEXUS_RO_USER=$ACUMOS_NEXUS_RO_USER
export ACUMOS_NEXUS_RO_USER_PASSWORD=$ACUMOS_NEXUS_RO_USER_PASSWORD
export ACUMOS_NEXUS_RW_USER=$ACUMOS_NEXUS_RW_USER
export ACUMOS_NEXUS_RW_USER_PASSWORD=$ACUMOS_NEXUS_RW_USER_PASSWORD
export ACUMOS_DOCKER_REGISTRY_USER=$ACUMOS_DOCKER_REGISTRY_USER
export ACUMOS_DOCKER_REGISTRY_PASSWORD=$ACUMOS_DOCKER_REGISTRY_PASSWORD
export ACUMOS_NEXUS_MAVEN_REPO_PATH=$ACUMOS_NEXUS_MAVEN_REPO_PATH
export ACUMOS_NEXUS_MAVEN_REPO=$ACUMOS_NEXUS_MAVEN_REPO
export ACUMOS_NEXUS_DOCKER_REPO=$ACUMOS_NEXUS_DOCKER_REPO
export ACUMOS_DOCKER_MODEL_PORT=$ACUMOS_DOCKER_MODEL_PORT
export ACUMOS_DOCKER_IMAGETAG_PREFIX=$ACUMOS_DOCKER_IMAGETAG_PREFIX
export NEXUS_DATA_PVC_NAME=$NEXUS_DATA_PVC_NAME
export NEXUS_DATA_PV_NAME=$NEXUS_DATA_PV_NAME
export NEXUS_DATA_PV_SIZE=$NEXUS_DATA_PV_SIZE
EOF

cat nexus_env.sh
