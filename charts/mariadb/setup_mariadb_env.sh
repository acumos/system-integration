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

if [[ -e mariadb_env.sh ]]; then source mariadb_env.sh; fi

export ACUMOS_MARIADB_NAMESPACE="${ACUMOS_MARIADB_NAMESPACE:-acumos-mariadb}"
export ACUMOS_MARIADB_DOMAIN="${ACUMOS_MARIADB_DOMAIN:-$ACUMOS_DOMAIN}"
export ACUMOS_INTERNAL_MARIADB_HOST="$ACUMOS_MARIADB_NAMESPACE-mariadb.$ACUMOS_MARIADB_NAMESPACE.svc.cluster.local"
export ACUMOS_MARIADB_HOST="${ACUMOS_MARIADB_HOST:-$ACUMOS_INTERNAL_MARIADB_HOST}"
if [[ "$ACUMOS_MARIADB_HOST" == "$ACUMOS_INTERNAL_MARIADB_HOST" ]]; then
  ACUMOS_MARIADB_HOST_IP=$ACUMOS_HOST_IP
elif [[ "$ACUMOS_MARIADB_HOST_IP" == "" ]]; then
  get_host_ip $ACUMOS_MARIADB_HOST
  ACUMOS_MARIADB_HOST_IP=$HOST_IP
fi
export MARIADB_MIRROR="${MARIADB_MIRROR:-sfo1.mirrors.digitalocean.com}"
export ACUMOS_MARIADB_VERSION="${ACUMOS_MARIADB_VERSION:-10.2}"
export ACUMOS_MARIADB_ADMIN_HOST="${ACUMOS_MARIADB_ADMIN_HOST:-$ACUMOS_HOST_IP}"
export ACUMOS_MARIADB_ROOT_ACCESS="${ACUMOS_MARIADB_ROOT_ACCESS:-true}"
export ACUMOS_MARIADB_PASSWORD="${ACUMOS_MARIADB_PASSWORD:-$(uuidgen)}"
export ACUMOS_MARIADB_USER="${ACUMOS_MARIADB_USER:-acumos_opr}"
export ACUMOS_MARIADB_USER_PASSWORD="${ACUMOS_MARIADB_USER_PASSWORD:-$(uuidgen)}"

export ACUMOS_MARIADB_DATA_PV_NAME="${ACUMOS_MARIADB_DATA_PV_NAME:-mariadb-data}"
export ACUMOS_MARIADB_DATA_PVC_NAME="${ACUMOS_MARIADB_DATA_PVC_NAME:-mariadb-data}"
export ACUMOS_MARIADB_DATA_PV_SIZE="${ACUMOS_MARIADB_DATA_PV_SIZE:-5Gi}"
export ACUMOS_MARIADB_DATA_PV_CLASSNAME="${ACUMOS_MARIADB_DATA_PV_CLASSNAME:-$ACUMOS_10GI_STORAGECLASSNAME}"
export ACUMOS_MARIADB_PORT="${ACUMOS_MARIADB_PORT:-3306}"
export ACUMOS_MARIADB_NODEPORT="${ACUMOS_MARIADB_NODEPORT:-}"
export ACUMOS_MARIADB_ADMINER_PORT="${ACUMOS_MARIADB_ADMINER_PORT:-3080}"
export ACUMOS_MARIADB_RUNASUSER="${ACUMOS_MARIADB_RUNASUSER:-}"

cat <<EOF >mariadb_env.sh
export ACUMOS_MARIADB_NAMESPACE=$ACUMOS_MARIADB_NAMESPACE
export ACUMOS_MARIADB_DOMAIN=$ACUMOS_MARIADB_DOMAIN
export ACUMOS_MARIADB_HOST=$ACUMOS_MARIADB_HOST
export ACUMOS_MARIADB_HOST_IP=$ACUMOS_MARIADB_HOST_IP
export MARIADB_MIRROR=$MARIADB_MIRROR
export ACUMOS_MARIADB_VERSION=$ACUMOS_MARIADB_VERSION
export ACUMOS_MARIADB_ADMIN_HOST=$ACUMOS_MARIADB_ADMIN_HOST
export ACUMOS_MARIADB_ROOT_ACCESS=$ACUMOS_MARIADB_ROOT_ACCESS
export ACUMOS_MARIADB_PASSWORD=$ACUMOS_MARIADB_PASSWORD
export ACUMOS_MARIADB_USER=$ACUMOS_MARIADB_USER
export ACUMOS_MARIADB_USER_PASSWORD=$ACUMOS_MARIADB_USER_PASSWORD
export ACUMOS_MARIADB_DATA_PV_NAME=$ACUMOS_MARIADB_DATA_PV_NAME
export ACUMOS_MARIADB_DATA_PVC_NAME=$ACUMOS_MARIADB_DATA_PVC_NAME
export ACUMOS_MARIADB_DATA_PV_SIZE=$ACUMOS_MARIADB_DATA_PV_SIZE
export ACUMOS_MARIADB_DATA_PV_CLASSNAME=$ACUMOS_MARIADB_DATA_PV_CLASSNAME
export ACUMOS_MARIADB_PORT=$ACUMOS_MARIADB_PORT
export ACUMOS_MARIADB_NODEPORT=$ACUMOS_MARIADB_NODEPORT
export ACUMOS_MARIADB_ADMINER_PORT=$ACUMOS_MARIADB_ADMINER_PORT
export ACUMOS_MARIADB_RUNASUSER=$ACUMOS_MARIADB_RUNASUSER
EOF

cat mariadb_env.sh
