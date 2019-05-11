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
  echo; echo "$(date +%Y-%m-%d:%H:%M:%SZ)	main	DEBUG	setup_nifi_certs.sh($fname:$fline)			user($nifiuser):$1" >>/maven/logs/pipeline-service/pipeline-service.log
}

setup_nifi_certs() {
  cd /maven/templates/conf/$nifiuser
  # Per https://access.redhat.com/solutions/82363
  log "Copy base signed and unsigned private keys"
  cp /maven/conf/nifi_key.pem .
  cp /maven/conf/apache_key.pem .

  log "Create NiFi server cert based on NiFi private key"
  openssl req -new -key nifi_key.pem -x509 -out nifi_cert.pem -days 365 \
    -passin pass:$CERT_KEY_PASSWORD \
    -subj "/C=US/ST=Unspecified/L=Unspecified/O=acumos/OU=acumos/CN=$nifiuser"

  log "Create server cert based on private key as used by nifi-registry"
  openssl req -new -key apache_key.pem -x509 -out apache_cert.pem -days 365 \
    -subj "/C=US/ST=Unspecified/L=Unspecified/O=acumos/OU=acumos/CN=$nifiuser"
  log "Create combined private key and server cert file for Apache"
  cat apache_key.pem apache_cert.pem > apache_proxy.pem

  log "Copy NiFi Registry Admin keystore as keystore for NiFi user"
  cp /maven/conf/nifi-keystore.p12 nifi-registry-keystore.p12

  log "Create JKS format truststore with CA cert"
  keytool -import -noprompt \
    -file apache_cert.pem \
    -alias nifi-ca \
    -keystore nifi-truststore.jks \
    -storepass $TRUSTSTORE_PASSWORD

  log "Import $MLWB_NIFI_REGISTRY_INITIAL_ADMIN cert into truststore with CA cert"
  cp /maven/conf/apache_cert.pem nifi_admin.pem
  keytool -import -noprompt \
    -file nifi_admin.pem \
    -alias nifi-registry-ca \
    -keystore nifi-truststore.jks \
    -storepass $TRUSTSTORE_PASSWORD

  if [[ $(kubectl get secret -n $ACUMOS_NAMESPACE nifi-certs-$nifiuser) ]]; then
    kubectl delete secret -n $ACUMOS_NAMESPACE nifi-certs-$nifiuser
  fi

  log "Create nifi-certs-$nifiuser secret"
  cp /maven/conf/nifi_cert.pem .
  kubectl create secret generic nifi-certs-$nifiuser -n $ACUMOS_NAMESPACE -o yaml \
    --from-file=apache_proxy.pem,nifi-truststore.jks,nifi-registry-keystore.p12
}

function update_templates() {
  cd /maven/templates/conf/$nifiuser
  cp /maven/templates/*.yaml .
#  log "Delete nifi resources for $nifiuser"
#  kubectl delete secret -n $ACUMOS_NAMESPACE nifi-certs-$nifiuser
#  kubectl delete configmap -n $ACUMOS_NAMESPACE nifi-configmap-$nifiuser
#  kubectl delete configmap -n $ACUMOS_NAMESPACE nifi-apache-configmap-$nifiuser
#  kubectl delete deployment -n $ACUMOS_NAMESPACE nifi-$nifiuser
#  kubectl delete service -n $ACUMOS_NAMESPACE nifi-service-$nifiuser
#  kubectl delete service -n $ACUMOS_NAMESPACE admin-nifi-$nifiuser
#  kubectl delete ingress -n $ACUMOS_NAMESPACE nifi-ingress-$nifiuser
#  while [[ $(kubectl get pods -n $ACUMOS_NAMESPACE | grep -c "nifi-$nifiuser") -gt 0 ]]; do
#    log "Waiting for pods nifi-$nifiuser to terminate"
#    sleep 10
#  done
  log "Update templates for $nifiuser"
  files="*.yaml"
  for f in $files; do
    sed -i -- "s/\$USER/$nifiuser/g" $f
#    kubectl create -f $f
  done
  chmod 777 /maven/templates/conf/$nifiuser/*.yaml
}

if [[ $# -lt 1 ]]; then
  fail 'user parameter not provided'
fi

WORK_DIR=$(pwd)
cd $(dirname "$0")
trap 'fail' ERR
while [[ ! -e /usr/local/bin/kubectl ]]; do
  curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/linux/amd64/kubectl
  if [[ -e kubectl ]]; then
    chmod +x ./kubectl
    mv ./kubectl /usr/local/bin/kubectl
  else
    log "Waiting for DNS issue to resolve"
    sleep 5;
  fi
done

nifiuser=$1
mkdir -p /maven/templates/conf/$nifiuser
chmod 777 /maven/templates/conf/$nifiuser
update_templates
setup_nifi_certs
cd $WORK_DIR
