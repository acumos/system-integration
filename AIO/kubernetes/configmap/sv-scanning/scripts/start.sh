#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2019 AT&T Intellectual Property. All rights reserved.
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
# What this is: script to initialize the security-verification service
#

function log() {
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  if [[ ! -d /maven/logs/security-verification/security-verification-server ]]; then
    mkdir -p /maven/logs/security-verification/security-verification-server
  fi
  echo; echo "$(date +%Y-%m-%d:%H:%M:%SZ), start.sh($fname:$fline), $1" >>/maven/logs/security-verification/security-verification-server/security-verification-server.log
}


set -x
cd /maven/scan
files=$(ls /maven/conf/licenses/*)
log "Copying from /maven/conf/licenses to scancode license folder: $files"
cp /maven/conf/licenses/* scancode-toolkit-3.0.2/src/licensedcode/data/licenses/.
files=$(ls /maven/conf/rules/*)
log "Copying from /maven/conf/rules to scancode rules folder: $files"
cp /maven/conf/rules/* scancode-toolkit-3.0.2/src/licensedcode/data/rules/.
files=$(ls /maven/conf/scripts/*)
log "Copying from /maven/conf/scripts to /maven/scan/: $files"
cp /maven/conf/scripts/* .
log "Setting up SV siteConfig verification key"
bash setup_verification_site_config.sh http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD $ACUMOS_ADMIN_USER
if [[ $? -ne 0 ]]; then exit 1; fi
log "Initializing scancode toolkit"
scancode-toolkit-3.0.2/scancode --license start.sh --json=/tmp/scancode.json
log "Starting the SV Scanning service"
cd /maven
java $JAVA_OPTS -Djava.security.egd=file:/dev/./urandom -jar /maven/security-verification-service-*.jar
log "SV Scanning service has exited"
