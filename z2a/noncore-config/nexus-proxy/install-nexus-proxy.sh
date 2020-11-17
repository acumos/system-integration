#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2020 AT&T Intellectual Property & Tech Mahindra.
# All rights reserved.
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
# Name: install-nexus.sh    - helper script to install Sonatype Nexus proxy

# Anchor the base directory for the util.sh helper
HERE=$(dirname $(readlink -f $0))
source $HERE/utils.sh
setup_logging

# Acumos Global Values Location
GV=$ACUMOS_GLOBAL_VALUE

# Acquire Namespace and Nexus Service values for Nexus
NAMESPACE=$(gv_read global.namespace)
CLUSTERNAME=$(gv_read global.clusterName)
#TODO: require a new key/value for nexus-proxy
RELEASE=$(gv_read global.acumosNexusRelease)
RELEASE=pyauth

log "Create nexus-proxy-pyauth Docker image ...."
# Build local image of the nexus-proxy
docker build -f Dockerfile.pyauth -t nexus-proxy-pyauth:v1.0 .

log "Loading nexus-proxy image into kind cluster ...."
# Load image into kind
kind load docker-image nexus-proxy-pyauth:v1.0 --name=$CLUSTERNAME

# Configuration logic
ACUMOS_AUTH_HOST=$(gv_read global.onboarding.svcName)
ACUMOS_AUTH_PORT=$(gv_read global.acumosOnboardingAppPort)
ACUMOS_CDS_HOST=$(gv_read global.cds.svcName)
ACUMOS_CDS_PORT=$(gv_read global.acumosCommonDataSvcPort)

ACUMOS_AUTH_URL="http://${ACUMOS_AUTH_HOST}:${ACUMOS_AUTH_PORT}/v2/auth/"
ACUMOS_CDS_URL="http://${ACUMOS_CDS_HOST}:${ACUMOS_CDS_PORT}/ccds"
ACUMOS_CDS_USER=$(gv_read global.acumosCdsUser)
ACUMOS_CDS_PASSWORD=$(gv_read global.acumosCdsPassword)
ACUMOS_DOCKER_PROXY_HOST=$(gv_read global.acumosDockerProxyHost)
ACUMOS_DOCKER_PROXY_PORT=$(gv_read global.acumosDockerProxyPort)

ACUMOS_DOCKER_PROXY_AUTH_API_PORT="8080"
ACUMOS_DOCKER_PROXY_AUTH_API_PATH="/auth"
ACUMOS_DOCKER_PROXY_LOG_FILE="/docker-proxy.log"
ACUMOS_DOCKER_PROXY_LOG_LEVEL="1"

# Strip comments from pyauth config file
PYE=pyauth-deployment-env.yaml
PYT=pyauth-deployment.tpl.yaml
PYY=pyauth-deployment.yaml
egrep -v '^\s*#' $PYT > $PYY

# Create pyauth environment template
cat > $PYE << EOF
- command: update
  path: spec.template.spec.containers[0].env[+]
  value:
    name: ACUMOS_AUTH_URL
    value: "${ACUMOS_AUTH_URL}"
- command: update
  path: spec.template.spec.containers[0].env[+]
  value:
    name: ACUMOS_CDS_URL
    value: "${ACUMOS_CDS_URL}"
- command: update
  path: spec.template.spec.containers[0].env[+]
  value:
    name: ACUMOS_CDS_USER
    value: "${ACUMOS_CDS_USER}"
- command: update
  path: spec.template.spec.containers[0].env[+]
  value:
    name: ACUMOS_CDS_PASSWORD
    value: "${ACUMOS_CDS_PASSWORD}"
- command: update
  path: spec.template.spec.containers[0].env[+]
  value:
    name: ACUMOS_DOCKER_PROXY_HOST
    value: "${ACUMOS_DOCKER_PROXY_HOST}"
- command: update
  path: spec.template.spec.containers[0].env[+]
  value:
    name: ACUMOS_DOCKER_PROXY_PORT
    value: "${ACUMOS_DOCKER_PROXY_PORT}"
EOF

# Merge environment template w/ pyauth yaml
yq w -i -s $PYE $PYY

# Apply pyauth manifest to k8s
kubectl apply -f $PYY -n $NAMESPACE

#log "Installing Nexus Helm Chart ...."
# Install the Nexus Helm Chart
# helm install $RELEASE --namespace $NAMESPACE -f $GV -f $HERE/nexus_value.yaml oteemocharts/sonatype-nexus

log "Waiting .... (up to 15 minutes) for pod ready status ...."
# Wait for the Nexus pods to become available
wait_for_pod_ready 900 $RELEASE   # seconds

RELEASE=nexus-proxy-nginx

#
GV_NEXUS_USER=$(gv_read global.acumosNexusUserName)
GV_NEXUS_PWD=$(gv_read global.acumosNexusUserPassword)

# Generate an X.509 cert and key
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
  -subj "/C=NA/ST=NA/L=Nexus/O=Acumos/OU=/CN=nexus-proxy/emailAddress=/" \
  -keyout config/server.key -out config/server.crt

# Create the configmap
kubectl create configmap -n $NAMESPACE $RELEASE \
      --from-file=config/

log "Installing ${RELEASE} manifest ...."
# Deploy the nexus-proxy-nginx pod
kubectl apply -f nginx-manifest.yaml -n $NAMESPACE

log "Waiting .... (up to 15 minutes) for pod ready status ...."
# Wait for the Nexus pods to become available
wait_for_pod_ready 900 $RELEASE   # seconds
kubectl get pods -o json

# write out logfile name
success
