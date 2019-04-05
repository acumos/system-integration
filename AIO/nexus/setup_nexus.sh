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
# - acumos_env.sh script prepared through oneclick_deploy.sh or manually, to
#   set install options (e.g. docker/k8s)
#
# Usage:
# For docker-based deployments, run this script on the AIO host.
# For k8s-based deployment, run this script on the AIO host or a workstation
# connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
# $ bash setup_nexus.sh <AIO_ROOT>
#   AIO_ROOT: path to AIO folder where environment files are
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
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script/ -d @nexus-script.json
  curl -v -X POST -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD -H "Content-Type: text/plain" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script/$1/run
}

function clean_nexus() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any existing docker based components for nexus-service"
    bash docker_compose.sh $AIO_ROOT down
  else
    log "Stop any existing k8s based components for nexus-service"
    if [[ ! -e deploy/nexus-service.yaml ]]; then
      mkdir -p deploy
      cp -r kubernetes/* deploy/.
      replace_env deploy
    fi
    stop_service deploy/nexus-service.yaml
    stop_deployment deploy/nexus-deployment.yaml
    log "Remove PVC for nexus-service"
    delete_pvc nexus-data $ACUMOS_NAMESPACE
  fi
}

function setup_nexus() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    bash docker_compose.sh $AIO_ROOT up -d --build --force-recreate
    wait_running nexus-service
  else
    log "Setup the nexus-data PVC"
    setup_pvc nexus-data $ACUMOS_NAMESPACE $NEXUS_DATA_PV_SIZE

    log "Deploy the k8s based components for nexus"
    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    replace_env deploy
    start_service deploy/nexus-service.yaml
    start_deployment deploy/nexus-deployment.yaml
    wait_running nexus $ACUMOS_NAMESPACE
  fi


  # Add -m 10 since for some reason curl seems to hang waiting for a response
  cmd="curl -v -m 10 \
    -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script"
  local i=0
  while [[ ! $($cmd) ]]; do
    log "Nexus API is not ready... waiting 10 seconds"
    sleep 10
    ((++i))
    if [[  $i -eq 60 ]]; then
      fail "Nexus API failed to respond"
    fi
  done

  setup_nexus_repo $ACUMOS_NEXUS_MAVEN_REPO 'Maven'
  setup_nexus_repo $ACUMOS_NEXUS_DOCKER_REPO 'Docker' $ACUMOS_DOCKER_MODEL_PORT

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

if [[ $# -lt 1 ]]; then
  echo <<'EOF'
Usage:
  For docker-based deployments, run this script on the AIO host.
  For k8s-based deployment, run this script on the AIO host or a workstation
  connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
  $ bash setup_nexus.sh <AIO_ROOT>
    AIO_ROOT: path to AIO folder where environment files are
EOF
  echo "All parameters not provided"
  exit 1
fi

WORK_DIR=$(pwd)
export AIO_ROOT=$1
source $AIO_ROOT/acumos_env.sh
source $AIO_ROOT/utils.sh
trap 'fail' ERR
cd $AIO_ROOT/nexus
clean_nexus
setup_nexus
cd $WORK_DIR
