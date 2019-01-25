#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2018 AT&T Intellectual Property. All rights reserved.
# ===================================================================================
# This Acumos software file is distributed by AT&T
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
#. What this is: script to update acumos-env.sh with user-provided cert values
#.
#. Prerequisites:
#. - acumos-env.sh script prepared through oneclick_deploy.sh or manually, to
#.   set install options (e.g. docker/k8s)
#. - host folder /var/$ACUMOS_NAMESPACE/certs created through setup-pv.sh
#.
#. Usage: intended to be called directly from oneclick_deploy.sh
#.

function update_cert_env() {
  log "Updating acumos-env.sh with \"export $1=$2\""
  sed -i -- "s/$1=.*/$1=$2/" ../acumos-env.sh
  export $1=$2
}

trap 'fail' ERR
source ../acumos-env.sh
source ../utils.sh
source cert-env.sh
update_cert_env ACUMOS_CERT_KEY_PASSWORD $CERT_KEY_PASSWORD
update_cert_env ACUMOS_KEYSTORE_PASSWORD $KEYSTORE_PASSWORD
update_cert_env ACUMOS_TRUSTSTORE_PASSWORD $TRUSTSTORE_PASSWORD
