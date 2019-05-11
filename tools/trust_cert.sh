#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2019 AT&T Intellectual Property. All rights reserved.
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
# What this is: Utility to add a trusted CA certificate to the set of trusted
# CAs for Acumos core components dependent upon CA trust (Federation). Typical
# use is to enable use of a self-signed server cert for a peered Acumos platform.
#
# Prerequisites:
# - Acumos AIO platform deployed, with access to the saved environment files
# - Run this script from the system-integration/tools folder on the Acumos host
# - Hostname/FQDN must be resolvable on the host where this script is run
#
# Usage:
# $ bash trust_cert.sh <cert> <alias>
#   cert: full path to cert file
#   alias: alias to associated with the cert (e.g. hostname)
#
# After running this script, restart the affected component e.g. federation.
#

function trust_cert() {
  trap 'fail' ERR
  cd $AIO_ROOT/certs/
  if [[ $(keytool -delete -alias $alias -keystore $ACUMOS_TRUSTSTORE -storepass $ACUMOS_TRUSTSTORE_PASSWORD -noprompt) ]]; then
    log "Prior alias in $ACUMOS_TRUSTSTORE deleted"
  fi
  keytool -import \
    -file $cert \
    -alias $alias \
    -keystore $ACUMOS_TRUSTSTORE \
    -storepass $ACUMOS_TRUSTSTORE_PASSWORD -noprompt

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    cp $ACUMOS_TRUSTSTORE /mnt/$ACUMOS_NAMESPACE/certs/.
  else
    val=$(sed ':a;N;$!ba;s/\n/\\n/g' $cert | sed "s/' '//g")
    kubectl patch configmap -n $ACUMOS_NAMESPACE acumos-certs \
      -p "{ \"data\": { "\"acumos-ca.crt\"": \"$val\" } }"
  fi
}

if [[ $# -lt 2 ]]; then
  cat <<'EOF'
 $ bash trust_cert.sh <cert> <alias>
   cert: full path to cert file
   alias: alias to associated with the cert (e.g. hostname)
EOF
  echo "All parameters not provided"
  exit 1
fi

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
export AIO_ROOT="$(cd ../AIO; pwd -P)"
source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh
cert=$1
alias=$2
trust_cert
cd $WORK_DIR
