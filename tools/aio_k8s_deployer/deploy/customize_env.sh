#!/bin/bash
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
# What this is: Script enabling overrides to the default environment variables
# used by the Acumos AIO tools, for Acumos core, MLWB, MariaDB, and ELK
#
# Prerequisites:
# - system-integration repo cloned placed into this folder
#
# Usage: intended to be called directly by aio_k8s_deployer.sh
#

set -x -e

function update_env() {
  sed -i -- "s~$1=.*~$1=$2~" $3
  export $1=$2
}

function update_acumos_env() {
  update_env $1 "$2" system-integration/AIO/acumos_env.sh
}

function update_mlwb_env() {
  update_env $1 "$2" system-integration/AIO/mlwb/mlwb_env.sh
}

function update_mariadb_env() {
  update_env $1 "$2" system-integration/charts/mariadb/setup_mariadb_env.sh
}

function update_elk_env() {
  update_env $1 "$2" system-integration/charts/elk-stack/setup_elk_env.sh
}

if [[ ! -e system-integration ]]; then
  echo "Please place a clone of the system-integration repo into this folder"
  exit 1
fi

# Recommended minimum values to customize (sample)
update_acumos_env DEPLOYED_UNDER k8s
update_acumos_env K8S_DIST generic
update_acumos_env ACUMOS_DOMAIN acumos.example.org
update_acumos_env ACUMOS_HOST acumos
update_acumos_env ACUMOS_HOST_USER ubuntu
