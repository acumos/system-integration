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

function stop_acumos_core_in_k8s() {
  trap 'fail' ERR
  apps=" azure-client cds docker-proxy dsce federation kubernetes-client msg \
    onboarding portal-be portal-fe sv-scanning"
  for app in $apps; do
    if [[ $(kubectl delete deployment -n $ACUMOS_NAMESPACE $app) ]]; then
      log "Deployment deleted for app $app"
    fi
    if [[ $(kubectl delete service -n $ACUMOS_NAMESPACE $app-service) ]]; then
      log "Service deleted for app $app"
    fi
  done
  cfgs="acumos-certs sv-scanning-licenses sv-scanning-rules sv-scanning-scripts"
  for cfg in $cfgs; do
    if [[ $(kubectl delete configmap -n $ACUMOS_NAMESPACE $cfg) ]]; then
      log "Configmap $cfg deleted"
    fi
  done
  if [[ "$ACUMOS_DEPLOY_INGRESS" == "true" ]]; then
    ings="cds-ingress kubernetes-client-ingress onboarding-ingress portal-ingress"
    for ing in $ings; do
      if [[ $(kubectl delete ingress -n $ACUMOS_NAMESPACE $ing) ]]; then
        log "Ingress $ing deleted"
      fi
    done
  fi
}

function stop_acumos() {
  trap 'fail' ERR
  if [[ "$ACUMOS_DEPLOY_MLWB" == "true" ]]; then
    bash mlwb/setup_mlwb.sh clean
  fi
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any running Acumos core docker-based components"
    bash $AIO_ROOT/docker_compose.sh down
  else
    if [[ "$MLWB_DEPLOY_JUPYTERHUB" == "true" ]]; then
      bash ../chartsjupyterhub/setup_jupyterhub.sh clean
    fi
    rm -rf deploy
    stop_acumos_core_in_k8s
  fi
  cleanup_snapshot_images
}

function prepare_env() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    log "Ensure kubectl access to the k8s cluster"
    if [[ ! $(kubectl get namespaces) ]]; then
      kubectl config view
      log 'Unable to access the k8s cluster using kubectl'
      fail 'Verify your kube configuration in ~/.kube/config'
    fi
  fi
  # TODO: redeploy without deleting all services first
  stop_acumos

  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    log "Ensure helm is ready"
    helm init --client-only
    log "Create PVCs in namespace $ACUMOS_NAMESPACE"
    setup_pvc $ACUMOS_NAMESPACE $ACUMOS_LOGS_PVC_NAME $ACUMOS_LOGS_PV_NAME $ACUMOS_LOGS_PV_SIZE
    create_acumos_registry_secret $ACUMOS_NAMESPACE
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

    log "Deploy Acumos core docker-based components"
    bash $AIO_ROOT/docker_compose.sh up -d --build
    bash $AIO_ROOT/docker-proxy/setup_docker_proxy.sh
  else
    log "Deploy the Acumos core components"
    if [[ ! -e deploy ]]; then mkdir deploy; fi
    local apps="cds federation portal-fe portal-be onboarding msg dsce \
kubernetes-client azure-client sv-scanning"
    for app in $apps; do
      start_acumos_core_app $app
    done

    log "Deploy docker-proxy"
    bash $AIO_ROOT/docker-proxy/setup_docker_proxy.sh
  fi
}

function setup_ingress() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    if [[ "$ACUMOS_DEPLOY_INGRESS" == "true" ]]; then
      if [[ "$ACUMOS_INGRESS_SERVICE" == "nginx" ]]; then
        bash $AIO_ROOT/../charts/ingress/setup_ingress_controller.sh $ACUMOS_NAMESPACE \
          $ACUMOS_HOST_IP $AIO_ROOT/certs/acumos.crt $AIO_ROOT/certs/acumos.key
        bash $AIO_ROOT/ingress/setup_ingress.sh
        update_acumos_env ACUMOS_ORIGIN $ACUMOS_DOMAIN force
        echo "Portal: https://$ACUMOS_DOMAIN" >acumos.url
      else
        bash $AIO_ROOT/kong/setup_kong.sh
        if [[ "$ACUMOS_KONG_PROXY_SSL_PORT" == "" ]]; then
          # Apply update to ACUMOS_KONG_PROXY_SSL_PORT
          source $AIO_ROOT/acumos_env.sh
        fi
        update_acumos_env ACUMOS_PORT $ACUMOS_KONG_PROXY_SSL_PORT force
        update_acumos_env ACUMOS_ORIGIN "$ACUMOS_DOMAIN:$ACUMOS_PORT" force
        echo "Portal: https://$ACUMOS_ORIGIN" >acumos.url
      fi
    fi
  else
    bash $AIO_ROOT/kong/setup_kong.sh
    update_acumos_env ACUMOS_ORIGIN $ACUMOS_DOMAIN force
    echo "Portal: https://$ACUMOS_ORIGIN" >acumos.url
  fi
}

function customize_catalog() {
  local catalog_index=$1
  local accessTypeCode=$2
  local name=$3
  local cdsapi="https://$ACUMOS_ORIGIN/ccds"
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
"url": "https://$ACUMOS_ORIGIN"
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
  log "Checking for 'self' peer entry for $ACUMOS_ORIGIN"
  local cdsapi="https://$ACUMOS_ORIGIN/ccds"
  local creds="$ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD"
  wait_until_success $ACUMOS_SUCCESS_WAIT_TIME "curl -k -u $creds -k $cdsapi/peer"
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

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
source utils.sh
update_acumos_env AIO_ROOT $WORK_DIR force
source acumos_env.sh
update_acumos_env DEPLOY_RESULT "" force
update_acumos_env FAIL_REASON "" force
set_k8s_env

get_host_ip $ACUMOS_HOST
update_acumos_env ACUMOS_HOST_IP $HOST_IP
update_acumos_env ACUMOS_JWT_KEY $(uuidgen)
update_acumos_env ACUMOS_CDS_PASSWORD $(uuidgen)
update_acumos_env ACUMOS_NEXUS_RO_USER_PASSWORD $(uuidgen)
update_acumos_env ACUMOS_NEXUS_RW_USER_PASSWORD $(uuidgen)
update_acumos_env ACUMOS_DOCKER_REGISTRY_PASSWORD $ACUMOS_NEXUS_RW_USER_PASSWORD
update_acumos_env ACUMOS_DOCKER_PROXY_USERNAME $(uuidgen)
update_acumos_env ACUMOS_DOCKER_PROXY_PASSWORD $(uuidgen)

log "Apply environment customizations to unset values in acumos_env.sh"
source acumos_env.sh

prepare_env
bash $AIO_ROOT/setup_keystore.sh

# Acumos components depend upon pre-configuration of Nexus (e.g. ports)
if [[ "$ACUMOS_DEPLOY_NEXUS" == "true" && "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  bash $AIO_ROOT/nexus/setup_nexus.sh
  # Prevent redeploy from reinstalling Nexus unless specifically requested
  update_acumos_env ACUMOS_DEPLOY_NEXUS false force
fi

# ELK and Acumos core components depend upon pre-configuration of MariaDB
if [[ "$ACUMOS_DEPLOY_MARIADB" == "true" && "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  source $AIO_ROOT/../charts/mariadb/setup_mariadb_env.sh
  bash $AIO_ROOT/mariadb/setup_mariadb.sh
  # Prevent redeploy from reinstalling MariaDB unless specifically requested
  update_acumos_env ACUMOS_DEPLOY_MARIADB false force
fi

# Supports use cases: MariaDB pre-setup (ACUMOS_DEPLOY_MARIADB=false),
# MariaDB new install, and database upgrade
if [[ "$ACUMOS_CDS_VERSION" != "$ACUMOS_CDS_PREVIOUS_VERSION" ]]; then
  update_acumos_env ACUMOS_SETUP_DB true
fi
if [[ "$ACUMOS_SETUP_DB" == "true" ]]; then
  bash $AIO_ROOT/setup_acumosdb.sh
  # Prevent redeploy from resetting database unless specifically requested
  update_acumos_env ACUMOS_CDS_PREVIOUS_VERSION $ACUMOS_CDS_VERSION force
fi

# Filebeat depends upon pre-configuration of the ELK stack
if [[ "$ACUMOS_DEPLOY_ELK" == "true" ]]; then
  bash $AIO_ROOT/elk-stack/setup_elk.sh
  # Prevent redeploy from reinstalling MariaDB unless specifically requested
  update_acumos_env ACUMOS_DEPLOY_ELK false force
fi

if [[ "$ACUMOS_DEPLOY_ELK_FILEBEAT" == "true" ]]; then
  bash $AIO_ROOT/beats/setup_beats.sh filebeat
fi
if [[ "$DEPLOYED_UNDER" == "docker" && "$ACUMOS_DEPLOY_ELK_METRICBEAT" == "true" ]]; then
  bash $AIO_ROOT/beats/setup_beats.sh metricbeat
fi

# Apply any env updates from above
source acumos_env.sh
if [[ "$ACUMOS_DEPLOY_INGRESS" == "true" ]]; then
  setup_ingress
fi
setup_acumos
setup_federation

if [[ "$ACUMOS_DEPLOY_MLWB" == "true" ]]; then
  bash $AIO_ROOT/mlwb/setup_mlwb.sh
fi

# Acumos components depend upon pre-configuration of the docker-engine
if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
  if [[ "$ACUMOS_DEPLOY_DOCKER_DIND" == "true" ]]; then
    bash $AIO_ROOT/docker-engine/setup_docker_engine.sh
  else
    update_acumos_env ACUMOS_DOCKER_API_HOST $ACUMOS_HOST_IP force
  fi
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
Common Data Service Swagger UI: https://$ACUMOS_ORIGIN/ccds/swagger-ui.html
Portal Swagger UI: https://$ACUMOS_ORIGIN/api/swagger-ui.html
Onboarding Service Swagger UI: https://$ACUMOS_ORIGIN/onboarding-app/swagger-ui.html
Kibana: http://$ACUMOS_DOMAIN:$ACUMOS_ELK_KIBANA_PORT/app/kibana
Nexus: http://$ACUMOS_DOMAIN:$ACUMOS_NEXUS_API_PORT
EOF
if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
  echo "Mariadb Admin: http://$ACUMOS_HOST_IP:$ACUMOS_MARIADB_ADMINER_PORT" >>acumos.url
fi
pvcs="$ACUMOS_LOGS_PVC_NAME $MARIADB_DATA_PVC_NAME $NEXUS_DATA_PVC_NAME $ACUMOS_ELASTICSEARCH_DATA_PVC_NAME $DOCKER_VOLUME_PVC_NAME"
for pvc in $pvcs; do
  pv=$(kubectl get pvc -n $ACUMOS_NAMESPACE -o json $pvc | jq -r ".spec.volumeName")
  echo "PVC $pvc is in host folder /mnt/$ACUMOS_NAMESPACE/$pv" >>acumos.url
done
cat acumos.url
