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
#. What this is: script to setup Acumos Nexus repos
#.
#. Prerequisites:
#. - acumos-env.sh script prepared through oneclick_deploy.sh or manually, to
#.   set install options (e.g. docker/k8s)
#.
#. Usage: intended to be called directly from oneclick_deploy.sh
#.

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
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script/ -d @nexus-script.json
  curl -v -X POST -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD -H "Content-Type: text/plain" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script/$1/run
}

function setup() {
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    sudo bash docker-compose.sh $AIO_ROOT down
  else
    stop_service deploy/nexus-service.yaml
    stop_deployment deploy/nexus-deployment.yaml
  fi

  log "Setup the nexus-data PV"
  bash $AIO_ROOT/setup-pv.sh setup pv nexus-data \
    $PV_SIZE_NEXUS_DATA "200:$USER"

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    sudo bash docker-compose.sh $AIO_ROOT up -d --build --force-recreate
  else
    log "Setup the nexus-data PVC"
    bash $AIO_ROOT/setup-pv.sh setup pvc nexus-data \
      $PV_SIZE_NEXUS_DATA

    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    replace_env deploy "ACUMOS_NAMESPACE ACUMOS_HOST ACUMOS_DOMAIN \
      ACUMOS_NEXUS_API_PORT ACUMOS_DOCKER_MODEL_PORT"

    start_service deploy/nexus-service.yaml
    start_deployment deploy/nexus-deployment.yaml
    fi

  wait_running nexus-service

  # Add -m 10 since for some reason curl seems to hang waiting for a response
  while ! curl -v -m 10 -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script ; do
    log "Waiting 10 seconds for nexus server to respond"
    sleep 10
  done

  setup_nexus_repo 'acumos_model_maven' 'Maven'
  setup_nexus_repo 'acumos_model_docker' 'Docker' $ACUMOS_DOCKER_MODEL_PORT

  log "Add nexus roles and users"
  cat <<EOF >nexus-script.json
{
  "name": "add-roles-users",
  "type": "groovy",
  "content": "security.addRole(\"$ACUMOS_NEXUS_RO_USER\", \"$ACUMOS_NEXUS_RO_USER\", \"Read Only\", [\"nx-search-read\", \"nx-repository-view-*-*-read\", \"nx-repository-view-*-*-browse\"], []); security.addRole(\"$ACUMOS_NEXUS_RW_USER\", \"$ACUMOS_NEXUS_RW_USER\", \"Read Write\", [\"nx-search-read\", \"nx-repository-view-*-*-read\", \"nx-repository-view-*-*-browse\", \"nx-repository-view-*-*-add\", \"nx-repository-view-*-*-edit\", \"nx-apikey-all\"], []); security.addUser(\"$ACUMOS_NEXUS_RO_USER\", \"Acumos\", \"Read Only\", \"$ACUMOS_ADMIN_EMAIL\", true, \"$ACUMOS_NEXUS_RO_USER_PASSWORD\", [\"$ACUMOS_NEXUS_RO_USER\"]); security.addUser(\"$ACUMOS_NEXUS_RW_USER\", \"Acumos\", \"Read Write\", \"$ACUMOS_ADMIN_EMAIL\", true, \"$ACUMOS_NEXUS_RW_USER_PASSWORD\", [\"$ACUMOS_NEXUS_RW_USER\"]);"
}
EOF
  curl -v -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD -H "Content-Type: application/json" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script/ -d @nexus-script.json
  # TODO: verify script creation
  curl -v -X POST -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD -H "Content-Type: text/plain" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script/add-roles-users/run

  log "Show nexus users"
  cat <<'EOF' >nexus-script.json
{
  "name": "list-users",
  "type": "groovy",
  "content": "import groovy.json.JsonOutput; import org.sonatype.nexus.security.user.User; users = security.getSecuritySystem().listUsers(); size = users.size(); log.info(\"User count: $size\"); return JsonOutput.toJson(users)"
}
EOF
  curl -v -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD -H "Content-Type: application/json" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script/ -d @nexus-script.json
  curl -v -X POST -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD -H "Content-Type: text/plain" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script/list-users/run
}

source $AIO_ROOT/acumos-env.sh
source $AIO_ROOT/utils.sh
if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  setup
fi
