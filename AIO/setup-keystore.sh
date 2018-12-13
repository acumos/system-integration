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

# Setup server cert, key, and keystore for the Kong reverse proxy
# Currently the certs folder is also setup via docker-compose.yaml as a virtual
# folder for the federation-gateway, which currently does not support http
# access via the Kong proxy (only direct https access)
# TODO: federation-gateway support for access via HTTP from Kong reverse proxy
function setup() {
  trap 'fail' ERR
  log "Install keytool"
  if [[ "$dist" == "ubuntu" ]]; then
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

  openssl genrsa -des3 -out  /var/$ACUMOS_NAMESPACE/certs/acumosCA.key -passout pass:$ACUMOS_KEYPASS 4096

  openssl req -x509 -new -nodes -key  /var/$ACUMOS_NAMESPACE/certs/acumosCA.key -sha256 -days 1024 \
   -config openssl.cnf -out  /var/$ACUMOS_NAMESPACE/certs/acumosCA.crt -passin pass:$ACUMOS_KEYPASS \
   -subj "/C=US/ST=Unspecified/L=Unspecified/O=Acumos/OU=Acumos/CN=$ACUMOS_DOMAIN"

  log "Create server certificate key"
  openssl genrsa -out  /var/$ACUMOS_NAMESPACE/certs/acumos.key -passout pass:$ACUMOS_KEYPASS 4096

  log "Create a certificate signing request for the server cert"
  # ACUMOS_HOST is used as CN since it's assumed that the client's hostname
  # is not resolvable via DNS for this AIO deploy
  openssl req -new -key  /var/$ACUMOS_NAMESPACE/certs/acumos.key -passin pass:$ACUMOS_KEYPASS \
    -out  /var/$ACUMOS_NAMESPACE/certs/acumos.csr \
    -subj "/C=US/ST=Unspecified/L=Unspecified/O=Acumos/OU=Acumos/CN=$ACUMOS_DOMAIN"

  log "Sign the CSR with the acumos CA"
  openssl x509 -req -in  /var/$ACUMOS_NAMESPACE/certs/acumos.csr -CA  /var/$ACUMOS_NAMESPACE/certs/acumosCA.crt \
    -CAkey  /var/$ACUMOS_NAMESPACE/certs/acumosCA.key -CAcreateserial -passin pass:$ACUMOS_KEYPASS \
    -extfile openssl.cnf -out  /var/$ACUMOS_NAMESPACE/certs/acumos.crt -days 500 -sha256

  log "Create PKCS12 format keystore with acumos server cert"
  openssl pkcs12 -export -in  /var/$ACUMOS_NAMESPACE/certs/acumos.crt -passin pass:$ACUMOS_KEYPASS \
    -inkey  /var/$ACUMOS_NAMESPACE/certs/acumos.key -certfile  /var/$ACUMOS_NAMESPACE/certs/acumos.crt \
    -out  /var/$ACUMOS_NAMESPACE/certs/acumos_aio.p12 -passout pass:$ACUMOS_KEYPASS

  log "Create JKS format truststore with acumos CA cert"
  keytool -import -file  /var/$ACUMOS_NAMESPACE/certs/acumosCA.crt -alias acumosCA -keypass $ACUMOS_KEYPASS \
    -keystore  /var/$ACUMOS_NAMESPACE/certs/acumosTrustStore.jks -storepass $ACUMOS_KEYPASS -noprompt
}

source $AIO_ROOT/acumos-env.sh
source $AIO_ROOT/utils.sh
setup
