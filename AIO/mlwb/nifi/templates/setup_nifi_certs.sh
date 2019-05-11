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
# What this is: Script to setup nifi-certs
#
# Usage:
# $ bash setup_nifi_certs.sh <user>
#   user: name of user to set as the common name (CN) field

function fail() {
  log "$1"
  exit 1
}

function log() {
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  echo; echo "$(date +%Y-%m-%d:%H:%M:%SZ)	main	DEBUG	dump_model.sh($fname:$fline)			user($nifiuser):$1" >>/maven/logs/pipeline-service/pipeline-service.log
}

setup_nifi_certs() {
  mkdir -p /maven/conf/certs/$nifiuser
  cd /maven/conf/certs/$nifiuser
  # Per https://access.redhat.com/solutions/82363
  log "Create private key"
  openssl genrsa -out apache_key.pem 1024
  log "Create server cert based on private key"
  openssl req -new -key apache_key.pem -x509 -out apache_cert.pem -days 365 \
    -subj "/C=US/ST=Unspecified/L=Unspecified/O=acumos/OU=acumos/CN=$nifiuser"
  log "Create combined private key and server cert file for Apache"
  cat apache_key.pem apache_cert.pem > apache_proxy.pem

  log "Create PKCS12 format keystore with server cert"
  if [[ -e nifi-keystore.jks ]]; then rm nifi-keystore.jks; fi
  openssl pkcs12 -export \
    -in apache_cert.pem \
    -inkey apache_key.pem \
    -certfile apache_cert.pem \
    -out nifi-keystore.p12 \
    -passout pass:<KEYSTORE_PASSWORD>

  log "Create JKS format truststore with CA cert"
  if [[ -e nifi-truststore.jks ]]; then rm nifi-truststore.jks; fi
  keytool -import \
    -file apache_cert.pem \
    -alias nifi-ca \
    -keystore nifi-truststore.jks \
    -storepass <TRUSTSTORE_PASSWORD> -noprompt

  log "Create nifi-certs-$nifiuser secret"
  kubectl create secret generic nifi-certs-$nifiuser -n <ACUMOS_NAMESPACE> -o yaml \
    --from-file=apache_proxy.pem,apache_cert.pem,nifi-truststore.jks,nifi-keystore.p12
}

if [[ $# -lt 1 ]]; then
  fail 'user parameter not provided'
fi

WORK_DIR=$(pwd)
cd $(dirname "$0")
trap 'fail' ERR
if [[ ! -e /usr/local/bin/kubectl ]]; then
  curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/linux/amd64/kubectl
  chmod +x ./kubectl
  mv ./kubectl /usr/local/bin/kubectl
fi
nifiuser=$1
setup_nifi_certs
cd $WORK_DIR
