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

# Acumos Global Values Location
GV=$Z2A_ACUMOS_BASE/global_value.yaml
# Acquire Nexus Password from global_value.yaml
GV_ADMIN_PASSWORD=$(yq r global_value.yaml global.acumosNexusAdminPassword)

# TODO: get the IP address of the k8s Pod running the Nexus service and inject it into the function call
# kubectl describe svc acumos-nexus-service -n acumos-dev1 | awk '/IP:/ {print $2}'

# Function to make API calls to Nexus
api() {
  ADMIN_PW=$(< ./admin.password)
  VERB=$1;shift
  case $VERB in
    GET) /usr/bin/curl -v -u admin:$ADMIN_PW 'http://127.0.0.1:8081/service/rest'$1
      ;;
    POST) /usr/bin/curl -v -u admin:$ADMIN_PW -H "Content-Type: application/json" -X POST -d "$2" 'http://127.0.0.1:8081/service/rest'$1
      ;;
    PUT) /usr/bin/curl -v -u admin:$ADMIN_PW -H "Content-Type: text/plain" -X PUT -d "$2" 'http://127.0.0.1:8081/service/rest'$1
      ;;
    DELETE) /usr/bin/curl -v -u admin:$ADMIN_PW -H "Content-Type: text/plain" -X DELETE -d "$2" 'http://127.0.0.1:8081/service/rest'$1
      ;;
  esac
}
function join(){ local IFS=','; echo "$*" ; }

# Nexus Setup - Task 1 - Set the Nexus Administrator Password
api PUT /beta/security/users/admin/change-password $GV_ADMIN_PASSWORD
echo $GV_ADMIN_PASSWORD > ./admin.password
# TODO: add API call to DISABLE anonymous access

# Nexus Setup - Task 2 - Create the Nexus Blob Store for Acumos
# /nexus-data is the default path on Nexus
# TODO: insert $GV_BLOB_DATAPATH into GV_BLOB_JSON
GV_BLOB_DATAPATH=$(yq r global_value.yaml global.acumosNexusDataPath)
GV_BLOB_STORE=$(yq r global_value.yaml global.acumosNexusBlobStore)
GV_BLOB_JSON='{ "type": "file", "path": "/'$GV_BLOB_DATAPATH'/blobs/'$GV_BLOB_STORE'", "name": "'$GV_BLOB_STORE'" }'
api POST /beta/blobstores/file "$GV_BLOB_JSON"
api GET /beta/blobstores/file/$GV_BLOB_STORE

# Nexus Setup - Task 3 - Create the Maven Repo for Acumos
GV_MAVEN_REPO=$(yq r global_value.yaml global.acumosNexusMavenRepo)
GV_MAVEN_JSON='{ "name": "'$GV_MAVEN_REPO'", "online": true, "storage": { "blobStoreName": "'$GV_BLOB_STORE'", "strictContentTypeValidation": true, "writePolicy": "ALLOW" }, "cleanup": null, "maven": { "versionPolicy": "RELEASE", "layoutPolicy": "STRICT" } }'
api POST /beta/repositories/maven/hosted "$GV_MAVEN_JSON"
api GET /beta/repositories | jq ".[]|select(.name==\"$GV_MAVEN_REPO\")"

# Nexus Setup - Task 4 - Create the Docker Repo for Acumos
GV_DOCKER_PORT=$(yq r global_value.yaml global.acumosNexusDockerPort)
GV_DOCKER_REPO=$(yq r global_value.yaml global.acumosNexusDockerRepo)
GV_DOCKER_JSON=$'{ "name": "'$GV_DOCKER_REPO'", "online": true, "storage": { "blobStoreName": "'$GV_BLOB_STORE'", "strictContentTypeValidation": true, "writePolicy": "ALLOW" }, "docker": { "v1Enabled": false, "forceBasicAuth": true, "httpPort": '$GV_DOCKER_PORT' } }'
api POST /beta/repositories/docker/hosted "$GV_DOCKER_JSON"
api GET /beta/repositories | jq ".[]|select(.name==\"$GV_DOCKER_REPO\")"

# Nexus Setup - Task 5 - Create a Nexus Role for Acumos
GV_NEXUS_ROLE=$(yq r global_value.yaml global.acumosNexusRole)
GV_NEXUS_DOCKER_PRIVS=$(join $(api GET /beta/security/privileges 2> /dev/null | jq '.[]|select(.name|contains("'$GV_DOCKER_REPO'-*"))|.name'))
GV_NEXUS_MAVEN_PRIVS=$(join $(api GET /beta/security/privileges 2> /dev/null | jq '.[]|select(.name|contains("'$GV_MAVEN_REPO'-*"))|.name'))
GV_NEXUS_OTHER_PRIVS='"nx-blobstores-read"'
GV_NEXUS_PRIVS_JSON='{ "id": "'$GV_NEXUS_ROLE'", "name": "'$GV_NEXUS_ROLE'", "privileges": [ '$GV_NEXUS_DOCKER_PRIVS', '$GV_NEXUS_MAVEN_PRIVS', '$GV_NEXUS_OTHER_PRIVS' ] }'
api POST /beta/security/roles "$GV_NEXUS_PRIVS_JSON"

# Nexus Setup - Task 6 - Create a Nexus User for Acumos
GV_NEXUS_USER=$(yq r global_value.yaml global.acumosNexusUserName)
GV_NEXUS_PWD=$(yq r global_value.yaml global.acumosNexusUserPassword)
GV_NEXUS_EMAIL=$(yq r global_value.yaml global.acumosNexusUserEmail)
GV_NEXUS_USER_JSON='{ "userId": "'$GV_NEXUS_USER'", "firstName": "Nexus", "lastName": "User", "emailAddress": "'$GV_NEXUS_EMAIL'", "password": "'$GV_NEXUS_PWD'", "status": "active", "roles": [ "'$GV_NEXUS_ROLE'" ] }'
api POST /beta/security/users "$GV_NEXUS_USER_JSON"
