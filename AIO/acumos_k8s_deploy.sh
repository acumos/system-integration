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
# What this is: Script used by a non-sudo user to deploy/manage the Acumos
# platform under generic k8s
#
# Prerequisites:
# - User workstation is Ubuntu Xenial/Bionic, Centos 7, or MacOS
# - acumos_k8s_prep.sh run by a sudo user
# - prepare a clone of the system-integration repo in the root folder of
#   your user account. This can be a fresh clone or a patched/updated clone.
# - As setup by acumos_k8s_prep.sh, make sure you have a folder "acumos" with
#   subfolders "env", "logs", and "certs". Put any customized environment files
#   and certs there, or use the ones provided by the sudo user that ran
#   acumos_k8s_prep.sh
#
# Usage:
# - cd ~/system-integration/AIO
# - bash acumos_k8s_deploy.sh
#

set -x
trap 'fail' ERR

function fail() {
  echo "fail at $(caller 0 | awk '{print $1}')"
  exit 1
}

function sedi () {
    sed --version >/dev/null 2>&1 && sed -i -- "$@" || sed -i "" "$@"
}

cp ~/acumos/env/*-env.sh .
cp -r ~/acumos/certs .
# Disable metricbeat while debugging issues
sedi "s/ACUMOS_DEPLOY_ELK_METRICBEAT=.*/ACUMOS_DEPLOY_ELK_METRICBEAT=false/" acumos-env.sh

stamp=$(date +"%y%m%d-%H%M%S")
log="aio_k8s_generic-$stamp.log"
bash oneclick_deploy.sh 2>&1 | tee ~/acumos/logs/$log
