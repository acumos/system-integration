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
# What this is: script to setup Acumos Nexus repos
#
# Prerequisites:
# - Nexus server installed or accessible
# - nexus_env.sh setup manually or via setup_nexus_env.sh
#
# Usage:
# $ bash setup_nexus_repos.sh
#

setup_nexus_repo() {
  trap 'fail' ERR
  log "Create Nexus repo $1"
  # For info on Nexus script API and groovy scripts, see
  # https://github.com/sonatype/nexus-book-examples/tree/nexus-3.x/scripting
  # https://help.sonatype.com/display/NXRM3/Examples
  # Create repo Parameters per javadoc
  # org.sonatype.nexus.repository.Repository createDockerHosted(String name,
  #   Integer httpPort,
  #   Integer httpsPort,
  #   String blobStoreName,
  #   boolean v1Enabled,
  #   boolean strictContentTypeValidation,
  #   org.sonatype.nexus.repository.storage.WritePolicy writePolicy)
  # Only first three parameters used due to unclear how to script blobstore
  # creation and how to specify writePolicy ('ALLOW' was not recognized)
  if [[ "$2" == "Maven" ]]; then
    cat <<EOF >nexus-script.json
{
  "name": "$1",
  "type": "groovy",
  "content": "repository.create${2}Hosted(\"$1\")"
}
EOF
  else
    cat <<EOF >nexus-script.json
{
  "name": "$1",
  "type": "groovy",
  "content": "repository.create${2}Hosted(\"$1\", $3, null)"
}
EOF
  fi
  curl -v -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD -H "Content-Type: application/json" \
    http://$host:$port/service/rest/v1/script/ -d @nexus-script.json
  curl -v -X POST -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD -H "Content-Type: text/plain" \
    http://$host:$port/service/rest/v1/script/$1/run
}

function setup_nexus_repos() {
  trap 'fail' ERR
  update_nexus_env ACUMOS_NEXUS_RO_USER_PASSWORD $(uuidgen)
  update_nexus_env ACUMOS_NEXUS_RW_USER_PASSWORD $(uuidgen)
  update_nexus_env ACUMOS_DOCKER_REGISTRY_PASSWORD $ACUMOS_NEXUS_RW_USER_PASSWORD
  update_nexus_env ACUMOS_DOCKER_PROXY_USERNAME $(uuidgen)
  update_nexus_env ACUMOS_DOCKER_PROXY_PASSWORD $(uuidgen)

  host=$ACUMOS_NEXUS_DOMAIN
  port=$ACUMOS_NEXUS_API_PORT

  setup_nexus_repo $ACUMOS_NEXUS_MAVEN_REPO 'Maven'
  setup_nexus_repo $ACUMOS_NEXUS_DOCKER_REPO 'Docker' 8082

  log "Add nexus roles and users"
  cat <<EOF >nexus-script.json
{
  "name": "add-roles-users",
  "type": "groovy",
  "content": "
    security.addRole(\"$ACUMOS_NEXUS_RO_USER\", \"$ACUMOS_NEXUS_RO_USER\",
      \"Read Only\", [\"nx-search-read\", \"nx-repository-view-*-*-read\",
      \"nx-repository-view-*-*-browse\"],[]);
    security.addRole(\"$ACUMOS_NEXUS_RW_USER\", \"$ACUMOS_NEXUS_RW_USER\",
      \"Read Write\", [\"nx-search-read\", \"nx-repository-view-*-*-read\",
      \"nx-repository-view-*-*-browse\", \"nx-repository-view-*-*-add\",
      \"nx-repository-view-*-*-edit\", \"nx-repository-view-*-*-delete\",
      \"nx-apikey-all\"], []);
    security.addUser(\"$ACUMOS_NEXUS_RO_USER\", \"Acumos\", \"Read Only\",
      \"$ACUMOS_ADMIN_EMAIL\", true, \"$ACUMOS_NEXUS_RO_USER_PASSWORD\",
      [\"$ACUMOS_NEXUS_RO_USER\"]);
    security.addUser(\"$ACUMOS_NEXUS_RW_USER\", \"Acumos\", \"Read Write\",
      \"$ACUMOS_ADMIN_EMAIL\", true, \"$ACUMOS_NEXUS_RW_USER_PASSWORD\",
      [\"$ACUMOS_NEXUS_RW_USER\"]);"
}
EOF
  curl -v -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD -H "Content-Type: application/json" \
    http://$host:$port/service/rest/v1/script/ -d @nexus-script.json
  # TODO: verify script creation
  curl -v -X POST -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD -H "Content-Type: text/plain" \
    http://$host:$port/service/rest/v1/script/add-roles-users/run

  log "Show nexus users"
  cat <<'EOF' >nexus-script.json
{
  "name": "list-users",
  "type": "groovy",
  "content": "
    import groovy.json.JsonOutput;
    import org.sonatype.nexus.security.user.User;
    users = security.getSecuritySystem().listUsers();
    size = users.size();
    log.info(\"User count: $size\"); return JsonOutput.toJson(users)"
}
EOF
  curl -v -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD -H "Content-Type: application/json" \
    http://$host:$port/service/rest/v1/script/ -d @nexus-script.json
  curl -v -X POST -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD -H "Content-Type: text/plain" \
    http://$host:$port/service/rest/v1/script/list-users/run

  log "Disable strict content validation, and enable write ('redeploy')"
  cat <<EOF >nexus-admin.json
{
  "action": "coreui_Repository",
  "method": "update",
  "data": [
    {
      "attributes": {
        "maven": {
          "versionPolicy": "RELEASE",
          "layoutPolicy": "STRICT"
        },
        "storage": {
          "blobStoreName": "default",
          "strictContentTypeValidation": false,
          "writePolicy": "ALLOW"
        }
      },
      "name": "acumos_model_maven",
      "format": "maven2",
      "type": "hosted",
      "url": "http://$host:$port/$ACUMOS_NEXUS_MAVEN_REPO_PATH/$ACUMOS_NEXUS_MAVEN_REPO/",
      "online": true
    }
  ]
  ,
  "type": "rpc",
  "tid": 18
}
EOF
  curl -v -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD \
    -H 'Content-Type: application/json' \
    -X POST $host:$port/service/extdirect \
    -d @nexus-admin.json
}

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ..; pwd -P)"; fi
source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh
setup_nexus_repos
cp nexus_env.sh $AIO_ROOT/.
cd $WORK_DIR
