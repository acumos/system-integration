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
# Name: config-nexus.sh   - helper script to configure Sonatype Nexus for Acumos

# Anchor the base directory for the util.sh helper
HERE=$(dirname $(readlink -f $0))
source $HERE/utils.sh
redirect_to $HERE/config.log

# Acumos Values
GV=$ACUMOS_GLOBAL_VALUE
NAMESPACE=$(gv_read global.namespace)
RELEASE=$(gv_read global.acumosNexusRelease)

NEXUS_ADMIN_PASSWORD=$(gv_read global.acumosNexusAdminPassword)
NEXUS_API_PORT=$(gv_read global.acumosNexusEndpointPort)
NEXUS_SVC=$(svc_lookup $RELEASE $NAMESPACE)
yq w -i $GV global.acumosNexusService $NEXUS_SVC

# Default password for Sonatype Nexus
echo admin123 > $HERE/admin.password

# ADMIN_URL="http://$NEXUS_SVC.$NAMESPACE:${NEXUS_API_PORT}/service/rest"
ADMIN_URL="http://localhost:${NEXUS_API_PORT}/service/rest"

# Function to make API calls to Nexus
# TODO: lookup port dynamically
CURL="/usr/bin/curl --noproxy '*' --connect-timeout 10 -v -4"
function api() {
  ADMIN_PW=$(< $HERE/admin.password)
  CMD="$CURL -u admin:$ADMIN_PW"
  VERB=$1;shift
  case $VERB in
    GET) CMD="$CMD $ADMIN_URL$1"
      ;;
    POST) CMD="$CMD -H 'Content-Type: application/json' -X POST -d '$2' $ADMIN_URL$1"
      ;;
    PUT) CMD="$CMD -H 'Content-Type: text/plain' -X PUT -d '$2' $ADMIN_URL$1"
      ;;
    DELETE) CMD="$CMD -H 'Content-Type: text/plain' -X DELETE -d '$2' $ADMIN_URL$1"
      ;;
  esac
  eval "$CMD"
}
function join(){ local IFS=','; echo "$*" ; }

# wait for pods to become ready
wait_for_pod_ready 900 $RELEASE  #seconds

log "Creating temporary port-forward ...."
PORT_FWD=service/$RELEASE
kubectl port-forward -n $NAMESPACE $PORT_FWD $NEXUS_API_PORT:$NEXUS_API_PORT &
while : ; do
    eval "$CURL -o /dev/null $ADMIN_URL" && break
    sleep 1
done

log "Performing Nexus configuration tasks ...."
# Nexus Setup - Task 1 - Set the Nexus Administrator Password
api PUT /beta/security/users/admin/change-password $NEXUS_ADMIN_PASSWORD
echo $NEXUS_ADMIN_PASSWORD > $HERE/admin.password
# TODO: add API call to DISABLE anonymous access

# Nexus Setup - Task 2 - Create the Nexus Blob Store for Acumos
# /nexus-data is the default path on Nexus
# TODO: insert $GV_BLOB_DATAPATH into GV_BLOB_JSON
# GV_BLOB_DATAPATH=$(gv_read global.acumosNexusDataPath)
GV_BLOB_STORE=$(gv_read global.acumosNexusBlobStore)
GV_BLOB_JSON='{ "type": "file", "path": "/nexus-data/blobs/'$GV_BLOB_STORE'", "name": "'$GV_BLOB_STORE'" }'
api POST /beta/blobstores/file "$GV_BLOB_JSON"
api GET /beta/blobstores/file/$GV_BLOB_STORE

# Nexus Setup - Task 3 - Create the Maven Repo for Acumos
GV_MAVEN_REPO=$(gv_read global.acumosNexusMavenRepo)
GV_MAVEN_JSON='{ "name": "'$GV_MAVEN_REPO'", "online": true, "storage": { "blobStoreName": "'$GV_BLOB_STORE'", "strictContentTypeValidation": true, "writePolicy": "ALLOW" }, "cleanup": null, "maven": { "versionPolicy": "RELEASE", "layoutPolicy": "STRICT" } }'
api POST /beta/repositories/maven/hosted "$GV_MAVEN_JSON"
api GET /beta/repositories | jq ".[]|select(.name==\"$GV_MAVEN_REPO\")"

# Nexus Setup - Task 4 - Create the Docker Repo for Acumos
GV_DOCKER_PORT=$(gv_read global.acumosNexusDockerPort)
GV_DOCKER_REPO=$(gv_read global.acumosNexusDockerRepo)
GV_DOCKER_JSON=$'{ "name": "'$GV_DOCKER_REPO'", "online": true, "storage": { "blobStoreName": "'$GV_BLOB_STORE'", "strictContentTypeValidation": true, "writePolicy": "ALLOW" }, "docker": { "v1Enabled": false, "forceBasicAuth": true, "httpPort": '$GV_DOCKER_PORT' } }'
api POST /beta/repositories/docker/hosted "$GV_DOCKER_JSON"
api GET /beta/repositories | jq ".[]|select(.name==\"$GV_DOCKER_REPO\")"

# Nexus Setup - Task 5 - Create a Nexus Role for Acumos
GV_NEXUS_ROLE=$(gv_read global.acumosNexusRole)
GV_NEXUS_DOCKER_PRIVS=$(join $(api GET /beta/security/privileges 2> /dev/null | jq '.[]|select(.name|contains("'$GV_DOCKER_REPO'-*"))|.name'))
GV_NEXUS_MAVEN_PRIVS=$(join $(api GET /beta/security/privileges 2> /dev/null | jq '.[]|select(.name|contains("'$GV_MAVEN_REPO'-*"))|.name'))
GV_NEXUS_OTHER_PRIVS='"nx-blobstores-read"'
GV_NEXUS_PRIVS_JSON='{ "id": "'$GV_NEXUS_ROLE'", "name": "'$GV_NEXUS_ROLE'", "privileges": [ '$GV_NEXUS_DOCKER_PRIVS', '$GV_NEXUS_MAVEN_PRIVS', '$GV_NEXUS_OTHER_PRIVS' ] }'
api POST /beta/security/roles "$GV_NEXUS_PRIVS_JSON"

# Nexus Setup - Task 6 - Create a Nexus User for Acumos
GV_NEXUS_USER=$(gv_read global.acumosNexusUserName)
GV_NEXUS_PWD=$(gv_read global.acumosNexusUserPassword)
GV_NEXUS_EMAIL=$(gv_read global.acumosNexusUserEmail)
GV_NEXUS_USER_JSON='{ "userId": "'$GV_NEXUS_USER'", "firstName": "Nexus", "lastName": "User", "emailAddress": "'$GV_NEXUS_EMAIL'", "password": "'$GV_NEXUS_PWD'", "status": "active", "roles": [ "'$GV_NEXUS_ROLE'" ] }'
api POST /beta/security/users "$GV_NEXUS_USER_JSON"

# Explicitly pkill running port-forward
pkill -f -9 $PORT_FWD
