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
# - All hostnames specified in acumos-env.sh must be DNS-resolvable on all hosts
#   (entries in /etc/hosts or in an actual DNS server)
# - For deployments behind proxies, set HTTP_PROXY and HTTPS_PROXY in acumos-env.sh
# - For kubernetes based deployment
#   - Kubernetes cluster deployed
#   - kubectl installed on user's workstation, and configured to use the kube
#     profile for the target cluster, e.g. though setup-kubectl.sh, e.g
#     $ wget https://raw.githubusercontent.com/acumos/kubernetes-client/master/deploy/private/setup-kubectl.sh
#     $ bash setup-kubectl.sh myk8smaster myuser mynamespace
# - Host preparation steps by an admin (or sudo user)
#   - Persistent volume pre-arranged and identified for PV-dependent components
#     in acumos-env.sh. setup-pv.sh may be used for this, e.g.
#     $ bash acumos-env.sh
#     $ bash setup-pv.sh setup pv logs $ACUMOS_NAMESPACE $ACUMOS_LOGS_PV_SIZE "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
#   - the User running this script must have been added to the "docker" group
#     $ sudo usermod <user> -G docker
#   - AIO prerequisites setup by sudo user via setup_AIO_prereqs.sh
#
# Usage: if deploying under docker, on the target host
# $ bash oneclick_deploy.sh docker <host>
#   docker: install all components other than the docker-engine using docker-compose
#   host: domain name of target host
#
# If deploying under kubernetes, on the user's workstation
# $ bash oneclick_deploy.sh k8s <host> <k8sdist>
#   k8s: install all components under kubernetes
#   host: domain name of k8s master node
#   k8sdist: k8s distribution, generic|openshift
#
# NOTE: if redeploying with an existing Acumos database, or to upgrade an
# existing Acumos CDS database, ensure that acumos-env.sh contains the following values
# from acumos-env.sh as updated when the previous version was installed, as
# these will not be updated by this script:
#   ACUMOS_MARIADB_PASSWORD
#   ACUMOS_MARIADB_USER_PASSWORD
# Also set:
#   ACUMOS_CDS_PREVIOUS_VERSION to the previous data version
#   ACUMOS_CDS_VERSION to the upgraded version (or to the current version if
#     just redeploying with an existing, current version database
#   ACUMOS_CDS_DB to the same as the previous installed database
#

function clean_env() {
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any running Acumos core docker-based components"
    source docker-compose.sh down
  else
    deps="azure-client cds cms docker-proxy dsce federation kubernetes-client \
msg onboarding portal-be portal-fe filebeat metricbeat"
    for dep in $deps; do
      $k8s_cmd delete deployment -n $ACUMOS_NAMESPACE $dep
    done
    svcs="azure-client-service cds-service cms-service docker-proxy dsce-service \
federation-service kubernetes-client-service msg-service onboarding-service \
portal-be-service portal-fe-service filebeat-service metricbeat-service"
    for svc in $svcs; do
      $k8s_cmd delete service -n $ACUMOS_NAMESPACE $svc
    done
    x=$(echo $deps | sed 's/ /|/g')
    y=$(echo $svcs | sed 's/ /|/g')
    n=$($k8s_cmd get deployment -n $ACUMOS_NAMESPACE | grep -c -E "$x")
    m=$($k8s_cmd get service -n $ACUMOS_NAMESPACE | grep -c -E "$y")
    while [[ $n -gt 0 || $m -gt 0 ]]; do
      log "$m services and $n deployments still exist, waiting 10 seconds"
      sleep 10
      n=$($k8s_cmd get deployment -n $ACUMOS_NAMESPACE | grep -c -E "$x")
      m=$($k8s_cmd get service -n $ACUMOS_NAMESPACE | grep -c -E "$y")
      $k8s_cmd get deployment -n $ACUMOS_NAMESPACE | grep -E "$x"
      $k8s_cmd get service -n $ACUMOS_NAMESPACE | grep -E "$y"
    done
  fi
}

function prepare_env() {
  # TODO: redeploy without deleting all services first
  clean_env

  if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
    log "Check if namespace/project already exists, and create if not"
    if [[ "$K8S_DIST" == "generic" ]]; then
      if [[ ! $(kubectl get namespace $ACUMOS_NAMESPACE) ]]; then
        log "Create namespace $ACUMOS_NAMESPACE"
        kubectl create namespace $ACUMOS_NAMESPACE
        wait_until_success "kubectl get namespace $ACUMOS_NAMESPACE"
      fi
    else
      if [[ ! $(oc get project $ACUMOS_NAMESPACE) ]]; then
        log "Create project $ACUMOS_NAMESPACE"
        oc new-project $ACUMOS_NAMESPACE
        wait_until_success "oc get project $ACUMOS_NAMESPACE"
        log "Workaround: Acumos AIO requires hostpath privilege for volumes"
        oc adm policy add-scc-to-user privileged -z default -n $ACUMOS_NAMESPACE
      fi
    fi
  fi
}

function docker_login() {
  wait_until_success \
    "docker login $1 -u $ACUMOS_PROJECT_NEXUS_USERNAME -p $ACUMOS_PROJECT_NEXUS_PASSWORD"
}

function setup_acumos() {
  trap 'fail' ERR
  log "Login to LF Nexus Docker repos, for Acumos project images"
  docker_login https://nexus3.acumos.org:10004
  docker_login https://nexus3.acumos.org:10003
  docker_login https://nexus3.acumos.org:10002

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Deploy Acumos core docker-based components"
    source docker-compose.sh up -d --build
    cd docker-proxy; source setup-docker-proxy.sh; cd $AIO_ROOT
  else
    if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
      # Can't recreate PVCs if redeploying since data will still exist there
      log "Create PVCs in namespace $ACUMOS_NAMESPACE"
      source setup-pv.sh setup pvc logs $ACUMOS_NAMESPACE $ACUMOS_LOGS_PV_SIZE

      if [[ $($k8s_cmd get secret -n $ACUMOS_NAMESPACE acumos-registry) ]]; then
        log "Deleting k8s secret acumos-registry, prior to recreating it"
        $k8s_cmd delete secret -n $ACUMOS_NAMESPACE acumos-registry
      fi

      log "Create k8s secret for image pulling from docker"
      b64=$(cat $HOME/.docker/config.json | base64 -w 0)
      cat <<EOF >acumos-registry.yaml
apiVersion: v1
kind: Secret
metadata:
  name: acumos-registry
  namespace: $ACUMOS_NAMESPACE
data:
  .dockerconfigjson: $b64
type: kubernetes.io/dockerconfigjson
EOF

      $k8s_cmd create -f acumos-registry.yaml
    fi

    if [[ ! -e deploy ]]; then mkdir deploy; fi
    cp kubernetes/service/* deploy/.
    cp kubernetes/deployment/* deploy/.

    log "Set variable values in k8s templates"
    replace_env deploy

    log "Deploy the Acumos core k8s-based components"
    # Create services first... see https://github.com/kubernetes/kubernetes/issues/16448
    for f in  deploy/*-service.yaml ; do
      log "Creating service from $f"
      $k8s_cmd create -f $f
    done
    for f in  deploy/*-deployment.yaml ; do
      log "Creating deployment from $f"
      $k8s_cmd create -f $f
    done

    log "Deploy docker-proxy"
    cd docker-proxy; source setup-docker-proxy.sh; cd $AIO_ROOT

    log "Wait for all Acumos core component pods to be Running"
    log "Wait for all Acumos pods to be Running"
    apps="azure-client cms cds dsce federation kubernetes-client msg onboarding \
      portal-be portal-fe"
    for app in $apps; do
      wait_running $app $ACUMOS_NAMESPACE
    done
  fi

  log "Customize aio-cms-host.yaml"
  sed -i -- "s~<ACUMOS_DOMAIN>~$ACUMOS_DOMAIN~g" aio-cms-host.yaml
}

function setup_federation() {
  trap 'fail' ERR
  log "Checking for 'self' peer entry for $ACUMOS_DOMAIN"
  wait_until_success \
    "curl -s -o $HOME/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -k https://$ACUMOS_HOST:$ACUMOS_KONG_PROXY_SSL_PORT/ccds/peer"
  if [[ "$(jq -r '.content[0].name' $HOME/json)" != "$ACUMOS_DOMAIN" ]]; then
    log "Create 'self' peer entry (required) via CDS API"
    curl -s -o $HOME/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -X POST \
      -k https://$ACUMOS_HOST:$ACUMOS_KONG_PROXY_SSL_PORT/ccds/peer -H "accept: */*" \
      -H "Content-Type: application/json" \
      -d "{ \"name\":\"$ACUMOS_DOMAIN\", \"self\": true, \"local\": false, \"contact1\": \"$ACUMOS_ADMIN_EMAIL\", \"subjectName\": \"$ACUMOS_DOMAIN\", \"apiUrl\": \"https://$ACUMOS_DOMAIN:$ACUMOS_FEDERATION_PORT\",  \"statusCode\": \"AC\", \"validationStatusCode\": \"PS\" }"
    if [[ "$(jq -r '.created' $HOME/json)" == "null" ]]; then
      cat $HOME/json
      fail "Peer entry creation failed"
    fi
  else
    log "Self peer entry already exists for $ACUMOS_DOMAIN"
  fi
}

function set_env() {
  log "Updating acumos-env.sh with \"export $1=$3\""
  sed -i -- "s/$1=.*/$1=$3/" acumos-env.sh
  export $1=$3
}

set -x
source acumos-env.sh
source utils.sh
get_host_info
export WORK_DIR=$(pwd)
update_env AIO_ROOT $WORK_DIR force
update_env DEPLOYED_UNDER $1 force
update_env ACUMOS_DOMAIN $2 force
update_env K8S_DIST $3 force
update_env DEPLOY_RESULT "" force
update_env FAIL_REASON "" force

if [[ "$ACUMOS_HOST_IP" == "" ]]; then
  log "Determining host IP address for $ACUMOS_DOMAIN"
  if [[ $(host $ACUMOS_DOMAIN | grep -c 'not found') -eq 0 ]]; then
    update_env ACUMOS_HOST_IP $(host $ACUMOS_DOMAIN | head -1 | cut -d ' ' -f 4)
  elif [[ $(grep -c -P " $ACUMOS_DOMAIN( |$)" /etc/hosts) -gt 0 ]]; then
    update_env ACUMOS_HOST_IP $(grep -P "$ACUMOS_DOMAIN( |$)" /etc/hosts | cut -d ' ' -f 1)
  else
    log "Please ensure $ACUMOS_DOMAIN is resolvable thru DNS or hosts file"
    fail "IP address of $ACUMOS_DOMAIN cannot be determined."
  fi
fi

# Local variables used here and in other sourced scripts
export HOST_OS=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
export HOST_OS_VER=$(grep -m 1 'VERSION_ID=' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')

if [[ "$DEPLOYED_UNDER" == "docker" ]];then
  # This supports the option to clean and redeploy with under a different env,
  # using the same customized acumos-env.sh file.
  update_env ACUMOS_HOST_OS $HOST_OS
  update_env ACUMOS_HOST_OS_VER $HOST_OS_VER
  update_env ACUMOS_HOST_USER $USER
else
  if [[ "$ACUMOS_HOST_USER" == "" ]]; then
    log "Determining default user for target deployment host (ubuntu|centos)"
    if [[ $(ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$ACUMOS_DOMAIN pwd) ]]; then
      update_env ACUMOS_HOST_USER ubuntu
    elif [[ $(ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no centos@$ACUMOS_DOMAIN pwd) ]]; then
      update_env ACUMOS_HOST_USER centos
    else
      log "Please set the value of ACUMOS_HOST_USER in acumos-env.sh"
      fail "Target host $ACUMOS_HOST_USER cannot be determined"
    fi
  fi
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $ACUMOS_HOST_USER@$ACUMOS_DOMAIN:/etc/os-release .
  ACUMOS_HOST_OS=$(grep --m 1 ID os-release | awk -F '=' '{print $2}' | sed 's/"//g')
  update_env ACUMOS_HOST_OS $ACUMOS_HOST_OS
  ACUMOS_HOST_OS_VER=$(cat os-release | grep -m 1 'VERSION_ID=' | awk -F '=' '{print $2}' | sed 's/"//g')
  update_env ACUMOS_HOST_OS_VER $ACUMOS_HOST_OS_VER
fi

hostip=$(/sbin/ip route get 8.8.8.8 | head -1 | sed 's/^.*src //' | awk '{print $1}')
update_env ACUMOS_ADMIN_HOST $hostip

if [[ "$DEPLOYED_UNDER" == "k8s" ]]; then
  if [[ "$K8S_DIST" == "openshift" ]]; then
    k8s_cmd=oc
    k8s_nstype=project
  else
    k8s_cmd=kubectl
    k8s_nstype=namespace
  fi
fi

update_env ACUMOS_CDS_PASSWORD $(uuidgen)
update_env ACUMOS_NEXUS_RO_USER_PASSWORD $(uuidgen)
update_env ACUMOS_NEXUS_RW_USER_PASSWORD $(uuidgen)
update_env ACUMOS_DOCKER_REGISTRY_PASSWORD $ACUMOS_NEXUS_RW_USER_PASSWORD
update_env ACUMOS_DOCKER_PROXY_USERNAME $(uuidgen)
update_env ACUMOS_DOCKER_PROXY_PASSWORD $(uuidgen)

if [[ -e mariadb-env.sh ]]; then
  # Replace default values in setup-mariadb-env.sh
  sed -i -- 's/ACUMOS_CDS_DB=.*/ACUMOS_CDS_DB=$ACUMOS_CDS_DB/' mariadb-env.sh
  sed -i -- 's/ACUMOS_CDS_VERSION=.*/ACUMOS_CDS_VERSION=$ACUMOS_CDS_VERSION/' mariadb-env.sh
  sed -i -- 's/ACUMOS_CDS_PREVIOUS_VERSION=.*/ACUMOS_CDS_PREVIOUS_VERSION=$ACUMOS_CDS_PREVIOUS_VERSION/' mariadb-env.sh
  source mariadb-env.sh
  if [[ $(grep -c '^source mariadb-env.sh' acumos-env.sh) -eq 0 ]]; then
    echo "source mariadb-env.sh" >>acumos-env.sh
  fi
fi

if [[ -e elk-env.sh ]]; then
  source elk-env.sh
  if [[ ! $(grep '^source elk-env.sh' acumos-env.sh) ]]; then
    echo "source elk-env.sh" >>acumos-env.sh
  fi
fi

log "Apply environment customizations to unset values in acumos-env.sh"
source acumos-env.sh

prepare_env
source setup-keystore.sh

if [[ "$DEPLOYED_UNDER" == "k8s" && "$ACUMOS_DEPLOY_DOCKER" == "true" ]]; then
  cd docker-engine; source setup-docker-engine.sh; cd $AIO_ROOT
fi

if [[ "$ACUMOS_DEPLOY_MARIADB" == "true" && "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  source ../charts/mariadb/setup-mariadb-env.sh
  cd mariadb; source setup-mariadb.sh; cd $AIO_ROOT
fi

# Supports use cases: MariaDB pre-setup (ACUMOS_DEPLOY_MARIADB=false),
# MariaDB new install, and database upgrade
if [[ "$ACUMOS_CDS_VERSION" != "$ACUMOS_CDS_PREVIOUS_VERSION" ]]; then
  update_env ACUMOS_SETUP_DB true
fi
if [[ "$ACUMOS_SETUP_DB" == "true" ]]; then
  source setup-acumosdb.sh
fi

setup_acumos

cd kong
source setup-kong.sh
cd $AIO_ROOT

if [[ "$ACUMOS_DEPLOY_NEXUS" == "true" && "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  cd nexus; source setup-nexus.sh; cd $AIO_ROOT
fi

if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  setup_federation
fi

if [[ "$ACUMOS_DEPLOY_ELK" == "true" ]]; then
  cd elk-stack
  source setup-elk.sh
  cd $AIO_ROOT
fi

if [[ "$ACUMOS_DEPLOY_ELK_BEATS" == "true" ]]; then
  cd beats
  source setup-beats.sh filebeat
  source setup-beats.sh metricbeat
  cd $AIO_ROOT
fi

set +x
save_logs

log "Deploy is complete."
echo "Component details and stdout logs up to this point have been saved at"
echo "/tmp/acumos/debug, e.g. for debugging or if you are really bored."
echo "You can access the Acumos portal and other services at the URLs below,"
echo "assuming hostname \"$ACUMOS_DOMAIN\" is resolvable from your workstation:"
echo "One optional/manual step remains: if needed, complete the Hippo CMS"
echo "config as described in https://docs.acumos.org/en/latest/submodules/system-integration/docs/oneclick-deploy/user-guide.html#install-process"

portal_base=https://$ACUMOS_DOMAIN:$ACUMOS_KONG_PROXY_SSL_PORT
cat <<EOF >acumos.url
Portal: $portal_base
Onboarding API: $portal_base/onboarding-app
Common Data Service: -k https://$ACUMOS_HOST:$ACUMOS_KONG_PROXY_SSL_PORT/ccds/swagger-ui.html
Kibana: http://$ACUMOS_ELK_DOMAIN:$ACUMOS_ELK_KIBANA_PORT/app/kibana
Hippo CMS: http://http://$ACUMOS_HOST/cms/console/?1&path=/
Nexus: http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT
Mariadb Admin: http://$ACUMOS_DOMAIN:$ACUMOS_MARIADB_ADMINER_PORT
Kong Admin: http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT
EOF
cat acumos.url
