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
#. What this is: script to setup host-mapped PVs under kubernetes or docker
#.
#. Prerequisites:
#. - acumos-env.sh script prepared through oneclick_deploy.sh or manually, to
#.   set install options (e.g. docker/k8s)
#. - host folder /var/$ACUMOS_NAMESPACE/certs created through setup-pv.sh
#.
#. Usage: intended to be called directly from oneclick_deploy.sh
#.

# Setup server cert, key, and keystore for Kong, Portal-BE, and Federation

function setup() {
  trap 'fail' ERR
  log "Install keytool"
  if [[ "$ACUMOS_HOST_OS" == "ubuntu" ]]; then
    sudo apt-get install -y openjdk-8-jre-headless
  else
    sudo yum install -y java-1.8.0-openjdk-headless
  fi

  if [[ ! -e /var/$ACUMOS_NAMESPACE/certs ]]; then
    log "Create /var/$ACUMOS_NAMESPACE/certs as cert storage folder"
    sudo mkdir -p /var/$ACUMOS_NAMESPACE/certs
    # Have to set user and group to allow pod access to PVs
    sudo chown $USER:$USER /var/$ACUMOS_NAMESPACE
    sudo chown $USER:$USER /var/$ACUMOS_NAMESPACE/certs
  else rm -rf /var/$ACUMOS_NAMESPACE/certs/*
  fi

  log "Create self-signing CA"
  # Customize openssl.cnf as this is needed to set CN (vs command options below)
  sed -i -- "s/<acumos-domain>/$ACUMOS_DOMAIN/" openssl.cnf
  sed -i -- "s/<acumos-host>/$ACUMOS_HOST/" openssl.cnf
  CA_KEY_PASSWORD=$(uuidgen)
  log "... Generate CA cert key"
  openssl genrsa -des3 -out  /var/$ACUMOS_NAMESPACE/certs/acumosCA.key \
    -passout pass:$CA_KEY_PASSWORD 4096
  log "... Create self-signed cert for the CA"
  openssl req -x509 -new -nodes -sha256 -days 1024 -config openssl.cnf \
   -key /var/$ACUMOS_NAMESPACE/certs/acumosCA.key \
   -passin pass:$CA_KEY_PASSWORD \
   -out /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_CA_CERT \
   -subj "/C=US/ST=Unspecified/L=Unspecified/O=Acumos/OU=Acumos/CN=$ACUMOS_DOMAIN"

  log "Create server certificate key"
  update_env ACUMOS_CERT_KEY_PASSWORD "$ACUMOS_CERT_KEY_PASSWORD" $(uuidgen)
  openssl genrsa \
    -out /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_CERT_KEY \
    -passout pass:$ACUMOS_CERT_KEY_PASSWORD 4096

  log "Create a certificate signing request (CSR) for the server using the key"
  # ACUMOS_HOST is used as CN since it's assumed that the client's hostname
  # is not resolvable via DNS for this AIO deploy
  openssl req -new \
    -key /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_CERT_KEY \
    -passin pass:$ACUMOS_CERT_KEY_PASSWORD \
    -out  /var/$ACUMOS_NAMESPACE/certs/acumos.csr \
    -subj "/C=US/ST=Unspecified/L=Unspecified/O=Acumos/OU=Acumos/CN=$ACUMOS_DOMAIN"

  log "Sign the CSR with the acumos CA"
  openssl x509 -req  -days 500 -sha256 \
    -in /var/$ACUMOS_NAMESPACE/certs/acumos.csr \
    -CA /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_CA_CERT \
    -CAkey  /var/$ACUMOS_NAMESPACE/certs/acumosCA.key \
    -CAcreateserial -passin pass:$CA_KEY_PASSWORD \
    -extfile openssl.cnf -out /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_CERT

  log "Create PKCS12 format keystore with acumos server cert"
  update_env ACUMOS_KEYSTORE_PASSWORD "$ACUMOS_KEYSTORE_PASSWORD" $(uuidgen)
  update_env ACUMOS_TRUSTSTORE_PASSWORD "$ACUMOS_TRUSTSTORE_PASSWORD" $(uuidgen)
  openssl pkcs12 -export \
    -in  /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_CERT \
    -inkey /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_CERT_KEY \
    -passin pass:$ACUMOS_CERT_KEY_PASSWORD \
    -certfile  /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_CERT \
    -out /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_KEYSTORE \
    -passout pass:$ACUMOS_KEYSTORE_PASSWORD

  log "Create JKS format truststore with acumos CA cert"
  keytool -import \
    -file /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_CA_CERT \
    -alias acumosCA \
    -keypass $ACUMOS_CERT_KEY_PASSWORD \
    -keystore  /var/$ACUMOS_NAMESPACE/certs/$ACUMOS_TRUSTSTORE \
    -storepass $ACUMOS_TRUSTSTORE_PASSWORD -noprompt
}

source $AIO_ROOT/acumos-env.sh
source $AIO_ROOT/utils.sh
if [[ "$ACUMOS_CERT_KEY_PASSWORD" == "" ]]; then
  log "CA/cert config is not provided - setting up CA, cert, keystore, truststore"
  setup
fi
