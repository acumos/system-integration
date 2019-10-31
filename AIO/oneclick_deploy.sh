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
# - For deployments behind proxies, set ACUMOS_HTTP_PROXY and ACUMOS_HTTPS_PROXY in acumos_env.sh
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
#  - If calling this script without first running setup_prereqs.sh, ensure that
#    these values have been set/updated in acumos_env.sh:
#    DEPLOYED_UNDER: k8s|docker
#    ACUMOS_DOMAIN: DNS or hosts-file resolvable FQDN of the Acumos platform
#    K8S_DIST: openshift|generic
#    ACUMOS_HOST:  DNS or hosts-file resolvable hostname of the Acumos host
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
  if [[ "$ACUMOS_DEPLOY_FEDERATION" == "true" ]]; then
    apps="cds azure-client deployment-client dsce federation \
      kubernetes-client msg license-profile-editor license-rtu-editor \
      onboarding portal-be portal-fe sv-scanning"
  else
    apps="cds azure-client deployment-client dsce \
      kubernetes-client msg license-profile-editor license-rtu-editor \
      onboarding portal-be portal-fe sv-scanning"
  fi
  for app in $apps; do
    if [[ $(kubectl delete deployment -n $ACUMOS_NAMESPACE $app) ]]; then
      log "Deployment deleted for app $app"
    fi
    if [[ $(kubectl delete service -n $ACUMOS_NAMESPACE $app-service) ]]; then
      log "Service deleted for app $app"
    fi
  done
  cfgs="acumos-certs sv-scanning"
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

function setup_jenkins() {
  trap 'fail' ERR
  bash $AIO_ROOT/../charts/jenkins/setup_jenkins.sh all $ACUMOS_NAMESPACE $ACUMOS_DOMAIN

  log "Download security-verification-scan config if not already present (and presumably customized)"
  if [[ ! -e deploy/security-verification ]]; then
    git clone https://gerrit.acumos.org/r/security-verification deploy/security-verification
  fi
  mkdir -p deploy/jenkins/acumos
  cp ~/.kube/config deploy/jenkins/acumos/kube-config
  grep ACUMOS_CDS acumos_env.sh >deploy/jenkins/acumos/acumos_env.sh
  grep ACUMOS_SECURITY_VERIFICATION_PORT acumos_env.sh >>deploy/jenkins/acumos/acumos_env.sh
  grep ACUMOS_NEXUS nexus_env.sh >>deploy/jenkins/acumos/acumos_env.sh
  cp -r deploy/security-verification/jenkins/scan deploy/jenkins/acumos/sv
  local pod=$(kubectl get pods -n $ACUMOS_NAMESPACE | awk '/jenkins/{print $1}')
  kubectl cp deploy/jenkins/acumos -n $ACUMOS_NAMESPACE $pod:/acumos

  log "Download default jobs if not already present (and presumably customized)"
  mkdir -p deploy/jenkins/jobs
  if [[ ! -e deploy/jenkins/jobs/solution-deploy.xml ]]; then
    wget https://raw.githubusercontent.com/acumos/model-deployments-deployment-client/master/config/jobs/jenkins/solution-deploy.xml \
      -O deploy/jenkins/jobs/solution-deploy.xml
    sedi "s/acumos-domain/$ACUMOS_DEFAULT_SOLUTION_DOMAIN/" \
      deploy/jenkins/jobs/solution-deploy.xml
    sedi "s/acumos-namespace/$ACUMOS_DEFAULT_SOLUTION_NAMESPACE/" \
      deploy/jenkins/jobs/solution-deploy.xml
  fi
  if [[ ! -e deploy/jenkins/jobs/security-verification-scan.xml ]]; then
    wget https://raw.githubusercontent.com/acumos/security-verification/master/jenkins/security-verification-scan.xml \
      -O deploy/jenkins/jobs/security-verification-scan.xml
  fi
  if [[ ! -e deploy/jenkins/jobs/initial-setup.xml ]]; then
    cp $AIO_ROOT/../charts/jenkins/jobs/initial-setup.xml deploy/jenkins/jobs/.
  fi

  local url="-k https://$ACUMOS_DOMAIN/jenkins/"
  local auth="-u $ACUMOS_JENKINS_USER:$ACUMOS_JENKINS_PASSWORD"
  check_name_resolves $ACUMOS_JENKINS_API_URL
  if [[ "$NAME_RESOLVES" == "true" ]]; then
    url=$ACUMOS_JENKINS_API_URL
  fi
  fs=$(ls -d1 deploy/jenkins/jobs/*)
  for f in $fs; do
    local job=$(basename $f | cut -d '.' -f 1)
    log "Create Jenkins job $job"
    curl -v -X POST ${url}createItem?name=$job $auth \
      -H "Content-Type:text/xml" \
      --data-binary @$f
  done

  log "Execute Jenkins initial-setup job"
  local pod=$(kubectl get pods -n $ACUMOS_NAMESPACE | awk '/jenkins/{print $1}')
  kubectl cp -n $ACUMOS_NAMESPACE ~/.kube/config $pod:/acumos/.
  curl -v -X POST ${url}job/initial-setup/build $auth

  log "Execute security-verification-scan setup job"
  curl -v -X POST ${url}job/security-verification-scan/build $auth \
    --data-urlencode json='{"parameter":[{"name":"solutionId","value":""},{"name":"revisionId","value":""},{"name":"userId","value":""}]}'

  update_acumos_env ACUMOS_DEPLOY_JENKINS false force
}

function setup_acumos() {
  trap 'fail' ERR

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
    if [[ "$ACUMOS_DEPLOY_FEDERATION" == "true" ]]; then
      apps="cds azure-client deployment-client dsce federation \
        kubernetes-client msg license-profile-editor license-rtu-editor \
        onboarding portal-be portal-fe sv-scanning"
    else
      apps="cds azure-client deployment-client dsce \
        kubernetes-client msg license-profile-editor license-rtu-editor \
        onboarding portal-be portal-fe sv-scanning"
    fi
    for app in $apps; do
      start_acumos_core_app $app
    done

    log "Deploy docker-proxy"
    bash $AIO_ROOT/docker-proxy/setup_docker_proxy.sh
  fi
}

function add_to_urls() {
  trap 'fail' ERR
  if [[ ! -e acumos.url || $(grep -c "$1" acumos.url) -eq 0 ]]; then
    log "Adding $1: $2 to acumos.url"
    echo "$1: $2" >>acumos.url
  else
    log "Updating acumos.url with $1: $2"
    sedi "s~/$1:.*~/$1: $2~" acumos.url
  fi
}

function setup_ingress() {
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    if [[ "$ACUMOS_DEPLOY_INGRESS" == "true" ]]; then
      if [[ "$ACUMOS_INGRESS_SERVICE" == "nginx" ]]; then
        bash $AIO_ROOT/ingress/setup_ingress.sh
        update_acumos_env ACUMOS_ORIGIN $ACUMOS_DOMAIN force
      else
        bash $AIO_ROOT/kong/setup_kong.sh
        if [[ "$ACUMOS_KONG_PROXY_SSL_PORT" == "" ]]; then
          # Apply update to ACUMOS_KONG_PROXY_SSL_PORT
          source $AIO_ROOT/acumos_env.sh
        fi
        update_acumos_env ACUMOS_PORT $ACUMOS_KONG_PROXY_SSL_PORT force
        update_acumos_env ACUMOS_ORIGIN "$ACUMOS_DOMAIN:$ACUMOS_PORT" force
      fi
    else
      update_acumos_env ACUMOS_ORIGIN $ACUMOS_DOMAIN force
      if [[ "$(kubectl get svc -n $ACUMOS_NAMESPACE $ACUMOS_NAMESPACE-nginx-ingress-controller)" != "" ]]; then
        bash $AIO_ROOT/ingress/setup_ingress.sh
      fi
    fi
  else
    bash $AIO_ROOT/kong/setup_kong.sh
    update_acumos_env ACUMOS_ORIGIN $ACUMOS_DOMAIN force
  fi
  add_to_urls Portal https://$ACUMOS_ORIGIN
}

function customize_catalog() {
  local old_name=$1
  local accessTypeCode=$2
  local name=$3
  cds_baseurl="-k https://$ACUMOS_DOMAIN/ccds"
  check_name_resolves cds-service
  if [[ "$NAME_RESOLVES" == "true" ]]; then
    cds_baseurl="http://cds-service:8000/ccds"
  fi
  local creds="$ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD"
  local cats=$(curl -s -u $creds $cds_baseurl/catalog | jq '.content | length')
  local cat=0
  while [[ $cat -lt $cats ]]; do
    if [[ "$(curl -s -u $creds $cds_baseurl/catalog | jq -r ".content[$cat].name")" == "$old_name" ]]; then
      local jsonin="/tmp/$(uuidgen)"
      local jsonout="/tmp/$(uuidgen)"
      cid=$(curl -s -u $creds $cds_baseurl/catalog | jq -r ".content[$cat].catalogId")
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
      curl -s -o $jsonout -u $creds -X PUT $cds_baseurl/catalog/$cid \
        -H "accept: */*" -H "Content-Type: application/json" \
        -d @$jsonin
      if [[ "$(jq '.status' $jsonout)" != "200" ]]; then
        cat $jsonin
        cat $jsonout
        fail "Catalog update failed"
      fi
      rm $jsonin
      rm $jsonout
    fi
    cat=$((cat+1))
  done
}

function setup_federation() {
  trap 'fail' ERR
  log "Checking for 'self' peer entry for $ACUMOS_ORIGIN"
  local cds_baseurl="-k https://$ACUMOS_DOMAIN/ccds"
  check_name_resolves cds-service
  if [[ $NAME_RESOLVES == "true" ]]; then
    cds_baseurl="http://cds-service:8000/ccds"
  fi
  local creds="$ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD"
  local t=0
  local jsonout="/tmp/$(uuidgen)"
  curl -s -o $jsonout -u $creds $cds_baseurl/peer
  while [[ $(grep -c numberOfElements $jsonout) -eq 0 ]]; do
    if [[ $t -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      fail "CDS API is not ready after $ACUMOS_SUCCESS_WAIT_TIME seconds"
    fi
    log "CDS API is not yet ready; waiting 10 seconds"
    t=$((t+10))
    sleep 10
    curl -s -o $jsonout -u $creds $cds_baseurl/peer
  done
  cat $jsonout
  local peers=$(jq '.content | length' $jsonout)
  local peer=0
  local found=no
  while [[ $peer -lt $peers ]]; do
    if [[ "$(jq -r ".content[$peer].name" $jsonout)" == "$ACUMOS_FEDERATION_DOMAIN" ]]; then
      found=yes
    fi
    peer=$((peer+1))
  done
  if [[ "$found" == "no" ]]; then
    log "Create 'self' peer entry (required) via CDS API"
    local jsonin="/tmp/$(uuidgen)"
    cat <<EOF >$jsonin
{
"name": "$ACUMOS_CERT_SUBJECT_NAME",
"self": true,
"local": false,
"contact1": "$ACUMOS_ADMIN_EMAIL",
"subjectName": "$ACUMOS_CERT_SUBJECT_NAME",
"apiUrl": "https://$ACUMOS_FEDERATION_DOMAIN:$ACUMOS_FEDERATION_PORT",
"statusCode": "AC",
"validationStatusCode": "PS"
}
EOF
    curl -s -o $jsonout -u $creds -X POST $cds_baseurl/peer \
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
  customize_catalog 'Public Models' PB "$name Public"
  customize_catalog 'Company Models' RS "$name Internal"
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

get_host_ip $ACUMOS_DOMAIN
update_acumos_env ACUMOS_DOMAIN_IP $HOST_IP force

get_host_ip $ACUMOS_HOST
update_acumos_env ACUMOS_HOST_IP $HOST_IP force
update_acumos_env ACUMOS_JWT_KEY $(uuidgen)
update_acumos_env ACUMOS_CDS_PASSWORD $(uuidgen)

log "Apply environment customizations to unset values in acumos_env.sh"
source acumos_env.sh

prepare_env
bash $AIO_ROOT/setup_keystore.sh

# Ingress controller setup needs to precede ingress creations
if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
  if [[ "$ACUMOS_DEPLOY_INGRESS" == "true" ]]; then
    if [[ "$ACUMOS_INGRESS_SERVICE" == "nginx" ]]; then
      EXTERNAL_IP=""
      if [[ "$ACUMOS_INGRESS_LOADBALANCER" == "false" ]]; then
        EXTERNAL_IP=$ACUMOS_DOMAIN_IP
      fi
      bash $AIO_ROOT/../charts/ingress/setup_ingress_controller.sh $ACUMOS_NAMESPACE \
        $AIO_ROOT/certs/acumos.crt $AIO_ROOT/certs/acumos.key $EXTERNAL_IP
    fi
    update_acumos_env ACUMOS_DEPLOY_INGRESS false force
  fi
fi

# Acumos components depend upon pre-configuration of Nexus (e.g. ports)
if [[ "$ACUMOS_DEPLOY_NEXUS" == "true" && "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  bash $AIO_ROOT/nexus/setup_nexus.sh all
  # Prevent redeploy from reinstalling Nexus unless specifically requested
  update_acumos_env ACUMOS_DEPLOY_NEXUS false force
fi
add_to_urls Nexus http://$NEXUS_DOMAIN:$ACUMOS_NEXUS_API_PORT

if [[ "$ACUMOS_DEPLOY_NEXUS_REPOS" == "true" && "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  bash $AIO_ROOT/nexus/setup_nexus_repos.sh all
  # Prevent redeploy from reinstalling Nexus unless specifically requested
  update_acumos_env ACUMOS_DEPLOY_NEXUS_REPOS false force
fi

# ELK and Acumos core components depend upon pre-configuration of MariaDB
if [[ "$ACUMOS_DEPLOY_MARIADB" == "true" && "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  source $AIO_ROOT/../charts/mariadb/setup_mariadb_env.sh
  bash $AIO_ROOT/mariadb/setup_mariadb.sh
  # Prevent redeploy from reinstalling MariaDB unless specifically requested
  update_acumos_env ACUMOS_DEPLOY_MARIADB false force
fi
# Apply any env updates from above
source acumos_env.sh

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

if [[ "$DEPLOYED_UNDER" == "k8s" && "$ACUMOS_DEPLOY_COUCHDB" == "true" ]]; then
  update_acumos_env ACUMOS_COUCHDB_PASSWORD $(uuidgen)
  bash $AIO_ROOT/../charts/couchdb/setup_couchdb.sh all $ACUMOS_NAMESPACE $ACUMOS_DOMAIN
  update_acumos_env ACUMOS_DEPLOY_COUCHDB false force
fi

if [[ "$ACUMOS_DEPLOY_JENKINS" == "true" ]]; then
  setup_jenkins
fi

# Filebeat depends upon pre-configuration of the ELK stack
if [[ "$ACUMOS_DEPLOY_ELK" == "true" ]]; then
  bash $AIO_ROOT/elk-stack/setup_elk.sh
  # Prevent redeploy from reinstalling MariaDB unless specifically requested
  update_acumos_env ACUMOS_DEPLOY_ELK false force
fi

if [[ "$ACUMOS_DEPLOY_ELK_FILEBEAT" == "true" ]]; then
  bash $AIO_ROOT/beats/setup_beats.sh filebeat
  update_acumos_env ACUMOS_DEPLOY_ELK_FILEBEAT false force
fi
if [[ "$DEPLOYED_UNDER" == "docker" && "$ACUMOS_DEPLOY_ELK_METRICBEAT" == "true" ]]; then
  bash $AIO_ROOT/beats/setup_beats.sh metricbeat
  update_acumos_env ACUMOS_DEPLOY_ELK_METRICBEAT false force
fi

# Acumos components depend upon pre-configuration of the docker-engine
if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
  if [[ "$ACUMOS_DEPLOY_DOCKER_DIND" == "true" ]]; then
    bash $AIO_ROOT/docker-engine/setup_docker_engine.sh
  else
    if [[ "$ACUMOS_DOCKER_API_HOST" == "docker-dind-service" ]]; then
      update_acumos_env ACUMOS_DOCKER_API_HOST $ACUMOS_HOST_IP force
    fi
  fi
else
  update_acumos_env ACUMOS_DOCKER_API_HOST $ACUMOS_HOST_IP force
fi

# Apply any env updates from above
source acumos_env.sh
setup_ingress

if [[ "$ACUMOS_DEPLOY_CORE" == "true" ]]; then
  setup_acumos
  log "Setup SV site-config"
  check_name_resolves sv-scanning-service
  if [[ $NAME_RESOLVES == "true" ]]; then
    sv_baseurl="http://sv-scanning-service:9082/"
  else
    sv_baseurl="-k https://$ACUMOS_DOMAIN/sv/"
  fi
  curl $sv_baseurl/update/siteConfig/verification
  update_acumos_env ACUMOS_DEPLOY_CORE false force
fi

if [[ "$ACUMOS_DEPLOY_FEDERATION" == "true" ]]; then
  setup_federation
fi

if [[ "$ACUMOS_DEPLOY_MLWB" == "true" ]]; then
  bash $AIO_ROOT/mlwb/setup_mlwb.sh
  update_acumos_env ACUMOS_DEPLOY_MLWB false force
fi

if [[ "$ACUMOS_DEPLOY_LUM" == "true" ]]; then
  bash $AIO_ROOT/lum/setup-lum.sh
  update_acumos_env ACUMOS_DEPLOY_LUM false force
  add_to_urls "License Usage Manager" http://$ACUMOS_DOMAIN/lum/
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

add_to_urls "Common Data Service Swagger UI" https://$ACUMOS_ORIGIN/ccds/swagger-ui.html
add_to_urls "Portal Swagger UI" https://$ACUMOS_ORIGIN/api/swagger-ui.html
add_to_urls "Onboarding Service Swagger UI" https://$ACUMOS_ORIGIN/onboarding-app/swagger-ui.html
if [[ "$ACUMOS_ELK_DOMAIN" != "" ]]; then
  add_to_urls Kibana http://$ACUMOS_ELK_DOMAIN:$ACUMOS_ELK_KIBANA_PORT/app/kibana
fi

if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
  add_to_urls "Mariadb Admin" http://$ACUMOS_HOST_IP:$ACUMOS_MARIADB_ADMINER_PORT
fi
cat acumos.url
