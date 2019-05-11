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
#. What this is: script to create a self-signed CA and server cert
#.
# Prerequisites:
#
# Usage:
# $ bash setup_certs.sh <name> <subject-name> ["alt-names"] ["alt-ips"]
#   name: name prefix to use in the generated files (e.g. acumos)
#   subject-name: primary domain name to associate
#   alt-names: quoted, space-delimited set of alternate names
#   alt-ips: quoted, space-delimited set of alternate IP addresses
#

function setup_certs() {
  trap 'fail' ERR
  log "Customize openssl.cnf as $name.cnf"
  if [[ "$HOST_OS" == "ubuntu" ]]; then
    cp /usr/lib/ssl/openssl.cnf ./$name.cnf
  else
    cp /etc/pki/tls/openssl.cnf ./$name.cnf
  fi
  sedi 's/^dir.*=.*/dir = ./g' $name.cnf
  sedi "s/cacert.pem/$name-ca.crt/g" $name.cnf
  sedi "s/cakey.pem/$name-ca.key/g" $name.cnf
  sedi "s/# copy_extensions = copy/copy_extensions = copy/" $name.cnf
  sedi 's/# extensions.*=.*/extensions = v3_req/' $name.cnf
  sedi 's/countryName_default.*/countryName_default = US/' $name.cnf
  sedi '/\[ v3_req \]/a \
subjectAltName = @alt_names\n\
# Included these for openssl x509 -req -extfile\n\
subjectKeyIdentifier=hash\n\
authorityKeyIdentifier=keyid,issuer' $name.cnf

  sedi 's/\[ v3_ca \]/\[ alt_names \]\n\n[ v3_ca \]/' $name.cnf
  sedi "/\[ alt_names \]/aDNS.1 = $sn" $name.cnf

  if [[ "$san" != "" ]]; then
    i=2
    for n in $san; do
      sedi "/\[ alt_names \]/aDNS.$i = $n" $name.cnf
      i=$((i+1))
    done
  fi

  if [[ "$saip" != "" ]]; then
    i=1
    for n in $saip; do
      sedi "/\[ alt_names \]/aIP.$i = $n" $name.cnf
      i=$((i+1))
    done
  fi

  log "Create self-signing CA"
  CA_KEY_PASSWORD=$(uuidgen)
  echo "export CA_KEY_PASSWORD=$CA_KEY_PASSWORD" >cert_env.sh
  log "... Generate CA cert key"
  openssl genrsa -des3 -out $name-ca.key -passout pass:$CA_KEY_PASSWORD 4096
  log "... Create self-signed cert for the CA"
  openssl req -x509 -new -nodes -sha256 -days 1024 -config $name.cnf \
    -key $name-ca.key \
    -passin pass:$CA_KEY_PASSWORD \
    -out $name-ca.crt \
    -subj "/C=US/ST=Unspecified/L=Unspecified/O=$sn/OU=$sn/CN=$sn"

  log "Create server certificate key"
  CERT_KEY_PASSWORD=$(uuidgen)
  echo "export CERT_KEY_PASSWORD=$CERT_KEY_PASSWORD" >>cert_env.sh
  openssl genrsa \
    -out $name.key \
    -passout pass:$CERT_KEY_PASSWORD 4096

  log "Create a certificate signing request (CSR) for the server using the key"
  openssl req -new \
    -key $name.key \
    -passin pass:$CERT_KEY_PASSWORD \
    -out  $name.csr \
    -subj "/C=US/ST=Unspecified/L=Unspecified/O=$sn/OU=$sn/CN=$sn"

  log "Sign the CSR with the CA"
  openssl x509 -req  -days 500 -sha256 -extfile $name.cnf \
    -in $name.csr \
    -CA $name-ca.crt \
    -CAkey $name-ca.key \
    -CAcreateserial -passin pass:$CA_KEY_PASSWORD \
    -out $name.crt

  log "Create PKCS12 format keystore with server cert"
  KEYSTORE_PASSWORD=$(uuidgen)
  echo "export KEYSTORE_PASSWORD=$KEYSTORE_PASSWORD" >>cert_env.sh
  openssl pkcs12 -export \
    -in $name.crt \
    -inkey $name.key \
    -passin pass:$CERT_KEY_PASSWORD \
    -certfile $name.crt \
    -out $name-keystore.p12 \
    -passout pass:$KEYSTORE_PASSWORD

  log "Create JKS format keystore with server cert"
  keytool -importkeystore -srckeystore $name-keystore.p12 \
    -srcstorepass $KEYSTORE_PASSWORD -srcstoretype pkcs12 \
    -destkeystore $name-keystore.jks -deststoretype jks \
    -storepass $KEYSTORE_PASSWORD -noprompt

  log "Create JKS format truststore with CA cert"
  if [[ -e $name-truststore.jks ]]; then rm $name-truststore.jks; fi
  TRUSTSTORE_PASSWORD=$(uuidgen)
  echo "export TRUSTSTORE_PASSWORD=$TRUSTSTORE_PASSWORD" >>cert_env.sh
  keytool -import \
    -file $name-ca.crt \
    -alias $name-ca \
    -keystore $name-truststore.jks \
    -storepass $TRUSTSTORE_PASSWORD -noprompt
}

if [[ $# -lt 2 ]]; then
  cat <<'EOF'
Usage:
  $ bash setup_certs.sh <name> <subject-name> ["alt-names"] ["alt-ips"]
    name: name prefix to use in the generated files (e.g. acumos)
    subject-name: primary domain name to associate
    alt-names: quoted, space-delimited set of alternate names
   alt-ips: quoted, space-delimited set of alternate IP addresses
EOF
  echo "All parameters not provided"
  exit 1
fi

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ..; pwd -P)"; fi
cd $WORK_DIR
source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh
export HOST_OS=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
name=$1
sn=$2
san=$3
saip=$4
setup_certs
cd $WORK_DIR
