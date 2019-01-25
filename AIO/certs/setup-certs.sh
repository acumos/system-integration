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
#. Prerequisites:
#. Usage:
#. $ bash setup-certs.sh subject-name ["alt-names"]
#.   subject-name: primary name to associate
#.   alt-names: quoted, space-delimited set of alternate names
#.

function fail() {
  log "$1"
  exit 1
}

function log() {
  set +x
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  echo; echo "$fname:$fline ($(date)) $1"
  set -x
}

function setup() {
  trap 'fail' ERR
  if [[ ! $(which keytool) ]]; then
    log "Install keytool"
    if [[ "$ACUMOS_HOST_OS" == "ubuntu" ]]; then
      sudo apt-get install -y openjdk-8-jre-headless
    else
      sudo yum install -y java-1.8.0-openjdk-headless
    fi
  fi

  log "Customize openssl.cnf as $sn.cnf"
  if [[ "$ACUMOS_HOST_OS" == "ubuntu" ]]; then
    cp /usr/lib/ssl/openssl.cnf ./$sn.cnf
  else
    cp /etc/pki/tls/openssl.cnf ./$sn.cnf
  fi
  sudo chown $USER:$USER $sn.cnf
  sed -i -- 's/^dir.*=.*/dir = ./g' $sn.cnf
  sed -i -- "s/cacert.pem/$sn-ca.crt/g" $sn.cnf
  sed -i -- "s/cakey.pem/$sn-ca.key/g" $sn.cnf
  sed -i -- "s/# copy_extensions = copy/copy_extensions = copy/" $sn.cnf
  sed -i -- 's/# extensions.*=.*/extensions = v3_req/' $sn.cnf
  sed -i -- 's/countryName_default.*/countryName_default = US/' $sn.cnf
  sed -i -- '/\[ v3_req \]/a \
subjectAltName = @alt_names\n\
# Included these for openssl x509 -req -extfile\n\
subjectKeyIdentifier=hash\n\
authorityKeyIdentifier=keyid,issuer'  $sn.cnf

  cat <<EOF >>$sn.cnf
[ alt_names ]

DNS.1 = $sn
EOF
  if [[ "$san" != "" ]]; then
    i=2
    for n in $san; do
      echo "DNS.$i = $n" >>$sn.cnf
      ((i++))
    done
  fi

  log "Create self-signing CA"
  CA_KEY_PASSWORD=$(uuidgen)
  echo "export CA_KEY_PASSWORD=$CA_KEY_PASSWORD" >cert-env.sh
  log "... Generate CA cert key"
  openssl genrsa -des3 -out $sn-ca.key -passout pass:$CA_KEY_PASSWORD 4096
  log "... Create self-signed cert for the CA"
  openssl req -x509 -new -nodes -sha256 -days 1024 -config $sn.cnf \
    -key $sn-ca.key \
    -passin pass:$CA_KEY_PASSWORD \
    -out $sn-ca.crt \
    -subj "/C=US/ST=Unspecified/L=Unspecified/O=$sn/OU=$sn/CN=$sn"

  log "Create server certificate key"
  CERT_KEY_PASSWORD=$(uuidgen)
  echo "export CERT_KEY_PASSWORD=$CERT_KEY_PASSWORD" >>cert-env.sh
  openssl genrsa \
    -out $sn.key \
    -passout pass:$CERT_KEY_PASSWORD 4096

  log "Create a certificate signing request (CSR) for the server using the key"
  openssl req -new \
    -key $sn.key \
    -passin pass:$CERT_KEY_PASSWORD \
    -out  $sn.csr \
    -subj "/C=US/ST=Unspecified/L=Unspecified/O=$sn/OU=$sn/CN=$sn"

  log "Sign the CSR with the acumos CA"
  openssl x509 -req  -days 500 -sha256 \
    -in $sn.csr \
    -CA $sn-ca.crt \
    -CAkey $sn-ca.key \
    -CAcreateserial -passin pass:$CA_KEY_PASSWORD \
    -out $sn.crt
#    -extfile $sn.cnf -out /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_CERT

  log "Create PKCS12 format keystore with server cert"
  KEYSTORE_PASSWORD=$(uuidgen)
  echo "export KEYSTORE_PASSWORD=$KEYSTORE_PASSWORD" >>cert-env.sh
  openssl pkcs12 -export \
    -in $sn.crt \
    -inkey $sn.key \
    -passin pass:$CERT_KEY_PASSWORD \
    -certfile $sn.crt \
    -out $sn-keystore.p12 \
    -passout pass:$KEYSTORE_PASSWORD

  log "Create JKS format truststore with CA cert"
  if [[ -e $sn-truststore.jks ]]; then rm $sn-truststore.jks; fi
  TRUSTSTORE_PASSWORD=$(uuidgen)
  echo "export TRUSTSTORE_PASSWORD=$TRUSTSTORE_PASSWORD" >>cert-env.sh
  keytool -import \
    -file $sn-ca.crt \
    -alias $sn-ca \
    -keystore $sn-truststore.jks \
    -storepass $TRUSTSTORE_PASSWORD -noprompt
}

export HOST_OS=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
export HOST_OS_VER=$(grep -m 1 'VERSION_ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
sn=$1
san=$2
setup
