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
# Name: config-kong.sh    - helper script to configure the Kong Service for Acumos
#
# Prerequisites:        - certificate and key needs to be provided before running
#                       this script.  The certificate and key MUST be installed in
#                       in the z2a/noncore-config/kong/certs directory.
#
# Kong API Service and Route Requirements
#
# Service:  name
#           upstream_url
#
# Route:    uris
#           service_id
#           methods/hosts/https-only
#

# Anchor the base directory for the util.sh helper
HERE=$(dirname $(readlink -f $0))
source $HERE/utils.sh
redirect_to $HERE/config.log

# Acumos Specific Values
NAMESPACE=$(gv_read global.namespace)
RELEASE=$(gv_read global.acumosKongRelease)

ACUMOS_CMS_PORT=$(gv_read global.acumosCmsPort)
ACUMOS_CRT=$HERE/certs/certificate.pem
ACUMOS_KEY=$HERE/certs/key.pem
ACUMOS_HOST_NAME=$(gv_read global.portal.portalFe.svcName).$NAMESPACE
ACUMOS_NEXUS_HOST_NAME=$(gv_read global.acumosNexusService).$NAMESPACE
ACUMOS_NEXUS_PORT=$(gv_read global.acumosNexusPort)
ACUMOS_HOME_PAGE_PORT=$(gv_read global.acumosPortalFePort)
ACUMOS_ONBOARDING_PORT=$(gv_read global.acumosOnboardingAppPort)

# Kong Specific Values
# TODO: make Kong chart use global_value.yaml service name
# KONG_SVC=$(svc_lookup $RELEASE $NAMESPACE)
KONG_SVC=acumos-kong
ACUMOS_KONG_API_HOST_NAME=$KONG_SVC.$NAMESPACE
ACUMOS_KONG_API_HOST_SNIS=$KONG_SVC.$NAMESPACE
# ACUMOS_KONG_API_PORT=$(gv_read global.acumosKongAdminPort)
ACUMOS_KONG_API_PORT=8444
# ADMIN_URL="https://${ACUMOS_KONG_API_HOST_NAME}:${ACUMOS_KONG_API_PORT}"
ADMIN_URL="https://localhost:${ACUMOS_KONG_API_PORT}"

PORT_FWD=deployment/$RELEASE
kubectl port-forward -n $NAMESPACE $PORT_FWD $ACUMOS_KONG_API_PORT:$ACUMOS_KONG_API_PORT &
while : ; do
    curl -k -o /dev/null $ADMIN_URL && break
    sleep 1
done

log "Installing certificate.\n"
# Install-certificates
CMD=(
curl -k -i -X POST $ADMIN_URL/certificates \
    -F "cert=@$ACUMOS_CRT" \
    -F "key=@$ACUMOS_KEY" \
    -F "snis=${ACUMOS_KONG_API_HOST_SNIS}"
)
eval ${CMD[*]}

log "\n\nAdding API to admin port.\n"

log "Creating Root API ...."
NAME=root

log "Creating Root API Services Definition ...."
# Root API Services definition
CMD=(
curl -i -k -X POST \
    --url $ADMIN_URL/services/ \
    --data "name=$NAME" \
    --data "url=http://${ACUMOS_HOST_NAME}:${ACUMOS_HOME_PAGE_PORT}"
)
eval ${CMD[*]}

log "Creating Root API Route Definition ...."
# Root API Route definition
CMD=(
curl -i -k -X POST \
    --url $ADMIN_URL/routes/ \
    --data "service.name=$NAME" \
    --data "name=$NAME" \
    --data "protocols[]=https" \
    --data "protocols[]=http" \
    --data "hosts[]=${ACUMOS_KONG_API_HOST_SNIS}" \
    --data "paths[]=/"
)
eval ${CMD[*]}

log "Enabling Bot-Detect for Root API ...."
# Enable Bot-Detect-root-api
CMD=(
curl -k -X POST $ADMIN_URL/services/$NAME/plugins \
    --data "name=bot-detection"
)
eval ${CMD[*]}

log "Enabling Rate-Limit for Root API ...."
# Enable Rate-Limit-root-api
CMD=(
curl -k -X POST $ADMIN_URL/services/$NAME/plugins \
    --data "name=rate-limiting"  \
    --data "config.second=150" \
    --data "config.hour=10000"
)
eval ${CMD[*]}

log "Creating Onboarding API ...."
NAME=onboarding-app

log "Creating Onboarding API Services Definition ...."
# Onboarding API Services definition
CMD=(
curl -i -k -X POST \
    --url $ADMIN_URL/services/ \
    --data "name=$NAME" \
    --data "url=https://${ACUMOS_HOST_NAME}:${ACUMOS_ONBOARDING_PORT}/$NAME" \
    --data "read_timeout=28800000" \
    --data "write_timeout=28800000"
)
eval ${CMD[*]}

log "Creating Onboarding API Route Definition ...."
# Onboarding API Route definition
CMD=(
curl -i -k -X POST \
    --url $ADMIN_URL/routes/ \
    --data "service.name=$NAME" \
    --data "name=$NAME" \
    --data "protocols[]=https" \
    --data "hosts[]=${ACUMOS_KONG_API_HOST_SNIS}" \
    --data "paths[]=/$NAME"
)
eval ${CMD[*]}

log "Enabling Bot-Detect for Onboarding API ...."
# Enable Bot-Detect-onboarding-app-api
CMD=(
curl -k -X POST $ADMIN_URL/services/$NAME/plugins \
    --data "name=bot-detection"
)
eval ${CMD[*]}

log "Enabling Rate-Limit for Onboarding API ...."
# Enable Rate-Limit-onboarding-app-api
CMD=(
curl -k -X POST $ADMIN_URL/services/$NAME/plugins \
    --data "name=rate-limiting"  \
    --data "config.second=50" \
    --data "config.hour=1000"
)
eval ${CMD[*]}

pkill -f -9 $PORT_FWD

log "\nKong API configuration completed successfully.\n\n"
