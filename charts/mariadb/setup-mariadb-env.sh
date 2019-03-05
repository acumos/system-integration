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
# What this is: Script to set environment file for mariadb installation.
# Prerequisites:
# - Ubuntu Xenial or Centos 7 server
# Usage:
# - Intended to be called from oneclick_deploy.sh and other scripts in this repo
#

if [[ -e mariadb-env.sh ]]; then source mariadb-env.sh; fi

export ACUMOS_MARIADB_NAMESPACE="${ACUMOS_MARIADB_NAMESPACE:-acumos-mariadb}"
export ACUMOS_CDS_VERSION="${ACUMOS_CDS_VERSION:-2.2}"
export ACUMOS_CDS_PREVIOUS_VERSION="${ACUMOS_CDS_PREVIOUS_VERSION:-}"
export ACUMOS_CDS_DB="${ACUMOS_CDS_DB:-acumos_cds}"
export ACUMOS_MARIADB_PASSWORD="${ACUMOS_MARIADB_PASSWORD:-$(uuidgen)}"
export ACUMOS_MARIADB_USER="${ACUMOS_MARIADB_USER:-acumos_opr}"
export ACUMOS_MARIADB_USER_PASSWORD="${ACUMOS_MARIADB_USER_PASSWORD:-$(uuidgen)}"
export MARIADB_DATA_PV_NAME="${MARIADB_DATA_PV_NAME:-pv-$ACUMOS_MARIADB_NAMESPACE-mariadb-data}"
export MARIADB_DATA_PVC_NAME="${MARIADB_DATA_PVC_NAME:-pvc-$ACUMOS_MARIADB_NAMESPACE-mariadb-data}"
export MARIADB_DATA_PV_SIZE="${MARIADB_DATA_PV_SIZE:-5Gi}"

cat <<EOF >mariadb-env.sh
export ACUMOS_MARIADB_NAMESPACE=$ACUMOS_MARIADB_NAMESPACE
export ACUMOS_CDS_VERSION=$ACUMOS_CDS_VERSION
export ACUMOS_CDS_PREVIOUS_VERSION=$ACUMOS_CDS_PREVIOUS_VERSION
export ACUMOS_CDS_DB=$ACUMOS_CDS_DB
export ACUMOS_MARIADB_PASSWORD=$ACUMOS_MARIADB_PASSWORD
export ACUMOS_MARIADB_USER=$ACUMOS_MARIADB_USER
export ACUMOS_MARIADB_USER_PASSWORD=$ACUMOS_MARIADB_USER_PASSWORD
export MARIADB_DATA_PV_NAME=$MARIADB_DATA_PV_NAME
export MARIADB_DATA_PVC_NAME=$MARIADB_DATA_PVC_NAME
export MARIADB_DATA_PV_SIZE=$MARIADB_DATA_PV_SIZE
EOF
