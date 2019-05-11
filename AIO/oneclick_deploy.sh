#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
# What this is: All-in-One deployment of the Acumos platform. FOR TEST PURPOSES
# ONLY.
#
# Prerequisites:
# - Ubuntu Xenial (16.04), Bionic (18.04), or Centos 7 hosts
# - All hostnames specified in acumos_env.sh must be DNS-resolvable on all hosts
#   (entries in /etc/hosts or in an actual DNS server)
# - For deployments behind proxies, set HTTP_PROXY and HTTPS_PROXY in acumos_env.sh
# - For kubernetes based deployment
#   - Kubernetes cluster deployed
#   - kubectl installed on user's workstation, and configured to use the kube
#     profile for the target cluster, e.g. though setup_kubectl.sh, e.g
#     $ wget https://raw.githubusercontent.com/acumos/kubernetes-client/master/deploy/private/setup_kubectl.sh
#     $ bash setup_kubectl.sh myk8smaster myuser mynamespace
# - Host preparation steps by an admin (or sudo user)
#   - Persistent volume pre-arranged and identified for PV-dependent components
#     in acumos_env.sh. tools/setup_pv.sh may be used for this
#   - the User running this script must have been added to the "docker" group
#     $ sudo usermod <user> -aG docker
#   - AIO prerequisites setup by sudo user via setup_prereqs.sh
#
# Usage:
#   For docker-based deployments, run this script on the AIO host.
#   For k8s-based deployment, run this script on the AIO host or a workstation
#   connected to the k8s cluster via kubectl (e.g. via tools/setup_kubectl.sh)
#   $ bash oneclick_deploy.sh
#
# NOTE: if redeploying with an existing Acumos database, or to upgrade an
# existing Acumos CDS database, ensure to update the following values
# from the current acumos_env.sh (as customized in the last install), as
# these will not be updated by this script:
#   ACUMOS_CDS_PREVIOUS_VERSION to the previous data version
#   ACUMOS_CDS_VERSION to the upgraded version (or to the current version if
#     just redeploying with an existing, current version database
#   ACUMOS_CDS_DB to the same as the previous installed database
#

function clean_env() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any running Acumos core docker-based components"
    bash $AIO_ROOT/docker_compose.sh down
  else
    delete_namespace $ACUMOS_NAMESPACE
    # Workaround for PVs getting stuck in "released" or "failed"
    pvs=$(kubectl get pv | awk '/Released/{print $1}')
    for pv in $pvs ; do
      kubectl patch pv $pv --type json -p '[{ "op": "remove", "path": "/spec/claimRef" }]'
    done
    pvs=$(kubectl get pv | awk '/Failed/{print $1}')
    for pv in $pvs ; do
      kubectl patch pv $pv --type json -p '[{ "op": "remove", "path": "/spec/claimRef" }]'
    done
  fi
  cleanup_snapshot_images
}

function prepare_env() {
  trap 'fail' ERR
  # TODO: redeploy without deleting all services first
  clean_env

  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    log "Check if namespace/project already exists, and create if not"
    create_namespace $ACUMOS_NAMESPACE
    if [[ "$K8S_DIST" == "openshift" ]]; then
        log "Workaround: Acumos AIO requires hostpath privilege for volumes"
        oc adm policy add-scc-to-user privileged -z default -n $ACUMOS_NAMESPACE
    fi
  fi
}

function setup_acumos() {
  trap 'fail' ERR

  mkdir -p kubernetes/configmap/sv-scanning/scripts
  mkdir -p kubernetes/configmap/sv-scanning/licenses
  mkdir -p kubernetes/configmap/sv-scanning/rules

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Login to LF Nexus Docker repos, for Acumos project images"
    docker_login https://nexus3.acumos.org:10004
    docker_login https://nexus3.acumos.org:10003
    docker_login https://nexus3.acumos.org:10002

    log "Prepare the sv-scanning config volume"
    rm -rf /mnt/$ACUMOS_NAMESPACE/sv/*
    cp -r kubernetes/configmap/sv-scanning/* /mnt/$ACUMOS_NAMESPACE/sv/.

    log "Deploy Acumos core docker-based components"
    bash $AIO_ROOT/docker_compose.sh up -d --build
    bash $AIO_ROOT/docker-proxy/setup_docker_proxy.sh
  else
    log "Create PVCs in namespace $ACUMOS_NAMESPACE"
    setup_pvc logs $ACUMOS_NAMESPACE $ACUMOS_LOGS_PV_SIZE
    create_acumos_registry_secret $ACUMOS_NAMESPACE

    if [[ ! -e deploy ]]; then mkdir deploy; fi
    cp kubernetes/service/* deploy/.
    cp kubernetes/deployment/* deploy/.
    cp kubernetes/rbac/* deploy/.

    log "Create the sv-scanning configmaps"
    kubectl create configmap -n $ACUMOS_NAMESPACE sv-scanning-scripts \
      --from-file=kubernetes/configmap/sv-scanning/scripts
    kubectl create configmap -n $ACUMOS_NAMESPACE sv-scanning-licenses \
      --from-file=kubernetes/configmap/sv-scanning/licenses
    kubectl create configmap -n $ACUMOS_NAMESPACE sv-scanning-rules \
      --from-file=kubernetes/configmap/sv-scanning/rules

    log "Set variable values in k8s templates"
    replace_env deploy

    log "Deploy the Acumos core k8s-based components"
    # Create services first... see https://github.com/kubernetes/kubernetes/issues/16448
    for f in  deploy/*-service.yaml ; do
      log "Creating service from $f"
      kubectl create -f $f
    done
    for f in  deploy/*-deployment.yaml ; do
      log "Creating deployment from $f"
      kubectl create -f $f
    done

    log "Deploy docker-proxy"
    bash $AIO_ROOT/docker-proxy/setup_docker_proxy.sh

    log "Wait for all Acumos core component pods to be Running"
    log "Wait for all Acumos pods to be Running"
    apps="azure-client cds dsce federation kubernetes-client msg onboarding \
      portal-be portal-fe"
    for app in $apps; do
      wait_running $app $ACUMOS_NAMESPACE
    done
  fi
}

function customize_catalog() {
  local catalog_index=$1
  local accessTypeCode=$2
  local name=$3
  local cdsapi="https://$ACUMOS_DOMAIN/ccds"
  local creds="$ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD"
  local jsonin="/tmp/$(uuidgen)"
  local jsonout="/tmp/$(uuidgen)"

  cid=$(curl -s -k -u $creds $cdsapi/catalog | jq -r ".content[$catalog_index].catalogId")
  cat <<EOF >$jsonin
{
"catalogId": "$cid",
"accessTypeCode": "$accessTypeCode",
"selfPublish": false,
"name": "$name",
"publisher": "$ACUMOS_DOMAIN",
"description": null,
"origin": null,
"url": "https://$ACUMOS_DOMAIN"
}
EOF
  curl -s -k -o $jsonout -u $creds -X PUT $cdsapi/catalog/$cid \
    -H "accept: */*" -H "Content-Type: application/json" \
    -d @$jsonin
  if [[ "$(jq '.status' $jsonout)" != "200" ]]; then
    cat $jsonin
    cat $jsonout
    fail "Catalog update failed"
  fi
  rm $jsonin
  rm $jsonout
}

function setup_federation() {
  trap 'fail' ERR
  log "Checking for 'self' peer entry for $ACUMOS_DOMAIN"
  # Have to use $ACUMOS_HOST vs $ACUMOS_DOMAIN as for some reason that does not
  # work in cloud VMs
  local cdsapi="https://$ACUMOS_DOMAIN/ccds"
  local creds="$ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD"
  wait_until_success 30 "curl -k -u $creds -k $cdsapi/peer"
  local jsonout="/tmp/$(uuidgen)"
  curl -s -k -o $jsonout -u $creds -k $cdsapi/peer
  if [[ "$(jq -r '.content[0].name' $jsonout)" != "$ACUMOS_DOMAIN" ]]; then
    log "Create 'self' peer entry (required) via CDS API"
    local jsonin="/tmp/$(uuidgen)"
    cat <<EOF >$jsonin
{
"name": "$ACUMOS_CERT_SUBJECT_NAME",
"self": true,
"local": false,
"contact1": "$ACUMOS_ADMIN_EMAIL",
"subjectName": "$ACUMOS_CERT_SUBJECT_NAME",
"apiUrl": "https://$ACUMOS_DOMAIN:$ACUMOS_FEDERATION_PORT",
"statusCode": "AC",
"validationStatusCode": "PS"
}
EOF
    curl -s -k -o $jsonout -u $creds -X POST $cdsapi/peer \
      -H "accept: */*" -H "Content-Type: application/json" \
      -d @$jsonin
    if [[ "$(jq -r '.created' $jsonout)" == "null" ]]; then
      cat $jsonout
      rm $jsonout $jsonin
      fail "Peer entry creation failed"
    fi
    rm $jsonin
  else
    log "Self peer entry already exists for $ACUMOS_DOMAIN"
  fi
  rm $jsonout

  log "Update default catalog attributes"  
  # Needed to avoid subscription issues due to conflicting catalog attributes,
  # i.e. peers cannot have the exact same catalog name
  # Note: the name must be less than 50 chars
  name=$(echo $ACUMOS_DOMAIN | cut -d '.' -f 1)
  customize_catalog 0 PB "$name Public"
  customize_catalog 1 RS "$name Internal"
}

function set_env() {
  log "Updating acumos_env.sh with \"export $1=$3\""
  sedi "s/$1=.*/$1=$3/" acumos_env.sh
  export $1=$3
}

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
source utils.sh
source acumos_env.sh
update_env AIO_ROOT $WORK_DIR force
update_env DEPLOY_RESULT "" force
update_env FAIL_REASON "" force
set_k8s_env

update_env ACUMOS_JWT_KEY $(uuidgen)
update_env ACUMOS_CDS_PASSWORD $(uuidgen)
update_env ACUMOS_NEXUS_RO_USER_PASSWORD $(uuidgen)
update_env ACUMOS_NEXUS_RW_USER_PASSWORD $(uuidgen)
update_env ACUMOS_DOCKER_REGISTRY_PASSWORD $ACUMOS_NEXUS_RW_USER_PASSWORD
update_env ACUMOS_DOCKER_PROXY_USERNAME $(uuidgen)
update_env ACUMOS_DOCKER_PROXY_PASSWORD $(uuidgen)

log "Apply environment customizations to unset values in acumos_env.sh"
source acumos_env.sh

prepare_env
bash $AIO_ROOT/setup_keystore.sh

if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
  if [[ "$ACUMOS_DEPLOY_DOCKER" == "true" ]]; then
    bash $AIO_ROOT/docker-engine/setup_docker_engine.sh
  else
    update_env ACUMOS_DOCKER_API_HOST $ACUMOS_HOST_IP force
  fi
fi

if [[ "$ACUMOS_DEPLOY_MARIADB" == "true" && "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  source $AIO_ROOT/../charts/mariadb/setup_mariadb_env.sh
  bash $AIO_ROOT/mariadb/setup_mariadb.sh
fi

# Supports use cases: MariaDB pre-setup (ACUMOS_DEPLOY_MARIADB=false),
# MariaDB new install, and database upgrade
if [[ "$ACUMOS_CDS_VERSION" != "$ACUMOS_CDS_PREVIOUS_VERSION" ]]; then
  update_env ACUMOS_SETUP_DB true
fi
if [[ "$ACUMOS_SETUP_DB" == "true" ]]; then
  bash $AIO_ROOT/setup_acumosdb.sh
fi

# Apply any env updates from above
source acumos_env.sh
setup_acumos

if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
  bash $AIO_ROOT/ingress/setup_ingress.sh
  echo "Portal: https://$ACUMOS_DOMAIN" >acumos.url
else
  bash $AIO_ROOT/kong/setup_kong.sh
  echo "Portal: https://$ACUMOS_DOMAIN" >acumos.url
fi

if [[ "$ACUMOS_DEPLOY_NEXUS" == "true" && "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  bash $AIO_ROOT/nexus/setup_nexus.sh
fi

setup_federation

if [[ "$ACUMOS_DEPLOY_ELK" == "true" ]]; then
  bash $AIO_ROOT/elk-stack/setup_elk.sh
fi

cd beats
if [[ "$ACUMOS_DEPLOY_ELK_FILEBEAT" == "true" ]]; then
  bash $AIO_ROOT/beats/setup_beats.sh filebeat
fi
if [[ "$DEPLOYED_UNDER" == "docker" && "$ACUMOS_DEPLOY_ELK_METRICBEAT" == "true" ]]; then
  bash $AIO_ROOT/beats/setup_beats.sh metricbeat
fi

if [[ "$ACUMOS_DEPLOY_MLWB" == "true" ]]; then
  bash $AIO_ROOT/mlwb/setup_mlwb.sh
fi

set +x

cd $AIO_ROOT
cat <<EOF >status.sh
DEPLOY_RESULT=success
FAIL_REASON=
EOF

sedi "s/DEPLOY_RESULT=.*/DEPLOY_RESULT=success/" acumos_env.sh

log "Deploy is complete."
echo "You can access the Acumos portal and other services at the URLs below,"
echo "assuming hostname \"$ACUMOS_DOMAIN\" is resolvable from your workstation:"

cat <<EOF >>acumos.url
Common Data Service Swagger UI: https://$ACUMOS_DOMAIN/ccds/swagger-ui.html
- if you have issues with using the CDS swagger over HTTPS, try the HTTP link
  http://$ACUMOS_DOMAIN:$ACUMOS_CDS_NODEPORT/ccds/swagger-ui.html
Portal Swagger UI: https://$ACUMOS_DOMAIN/api/swagger-ui.html
Onboarding Service Swagger UI: https://$ACUMOS_DOMAIN/onboarding-app/swagger-ui.html
Kibana: http://$ACUMOS_DOMAIN:$ACUMOS_ELK_KIBANA_PORT/app/kibana
Nexus: http://$ACUMOS_DOMAIN:$ACUMOS_NEXUS_API_PORT
EOF
if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
  echo "Mariadb Admin: http://$ACUMOS_HOST_IP:$ACUMOS_MARIADB_ADMINER_PORT" >>acumos.url
fi
cat acumos.url
