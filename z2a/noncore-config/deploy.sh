#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2020 AT&T Intellectual Property & Tech Mahindra.
# All rights reserved.
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
# Name: deploy.sh      - z2a noncore-config/deploy.sh deployment script
#
# Usage:
#

# error function
function error {
  echo "ERROR: $@" 1>&2
  exit 1
}

# deploy function
function deploy {
  set -e
  cp utils.sh.tpl ${1}/utils.sh
  cd ${1}/
  if [ -x install-${1}.sh ] ; then ./install-${1}.sh ; else true ; fi
  if [ -x config-${1}.sh ] ; then ./config-${1}.sh ; else true ; fi
}

# test for Acumos global values environment
if [[ -z "$ACUMOS_GLOBAL_VALUE" ]] ; then
  error  "ACUMOS_GLOBAL_VALUE is empty"
fi

# do the magic
case ${1} in
  ingress|mariadb-cds|nexus|license-usage-manager|license-manager) deploy ${1} ;;
  *) error "Unknown module [${1}]" ;;
esac
