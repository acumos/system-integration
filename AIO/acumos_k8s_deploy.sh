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
# - Ubuntu Xenial/Bionic or Centos 7 server
# - acumos_k8s_prep.sh run by a sudo user
#
# Usage:
# - bash acumos_k8s_deploy.sh [clone]
#   clone: if "clone", the current system-integration repo will be cloned.
#     Otherwise place the system-integration version to be used at
#     ~/system-integration
#

set -x
trap 'fail' ERR

function fail() {
  echo "fail at $(caller 0 | awk '{print $1}')"
  exit 1
}

clone=$1

if [[ "$clone" == "clone" ]]; then
  if [[ -d system-integration ]]; then rm -rf system-integration; fi
  git clone https://gerrit.acumos.org/r/system-integration
fi

cd ~/system-integration/AIO
cp ~/acumos/env/*-env.sh .
cp -r ~/acumos/certs .
# Disable metricbeat while debugging issues
sed -i -- "s/ACUMOS_DEPLOY_ELK_METRICBEAT=.*/ACUMOS_DEPLOY_ELK_METRICBEAT=false/" acumos-env.sh

stamp=$(date +"%y%m%d-%H%M%S")
log="aio_k8s_generic-$stamp.log"
bash oneclick_deploy.sh 2>&1 | tee ~/acumos/logs/$log
