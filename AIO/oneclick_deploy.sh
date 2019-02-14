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
# - Persistent volume pre-arranged and identified for PV-dependent components
#   in acumos-env.sh. setup-pv.sh may be used for this, e.g.
#   $ bash acumos-env.sh
#   $ bash setup-pv.sh setup pv logs $ACUMOS_LOGS_PV_SIZE "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
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

function setup_prereqs() {
  trap 'fail' ERR

  log "/etc/hosts customizations"
  # Ensure cluster hostname resolves inside the cluster
  if [[ $(host $ACUMOS_DOMAIN | grep -c 'not found') -gt 0 ]]; then
    if [[ $(grep -c -P " $ACUMOS_DOMAIN( |$)" /etc/hosts) -eq 0 ]]; then
      echo; echo "prereqs.sh: ($(date)) Add $ACUMOS_DOMAIN to /etc/hosts"
      echo "$ACUMOS_DOMAIN $ACUMOS_HOST" | sudo tee -a /etc/hosts
    fi
  fi

  log "/etc/hosts:"
  cat /etc/hosts

  log "Basic prerequisites"
  if [[ "$HOST_OS" == "ubuntu" ]]; then
    wait_dpkg; sudo apt-get update
    # TODO: fix need to skip upgrade as this sometimes updates the kube-system
    # services and they then stay in "pending", blocking k8s-based deployment
    # Also on bionic can cause a hang at 'Preparing to unpack .../00-systemd-sysv_237-3ubuntu10.11_amd64.deb ...'
    #  wait_dpkg; sudo apt-get upgrade -y
    wait_dpkg; sudo apt-get install -y wget git jq
  else
    # For centos, only deployment under k8s is supported
    # docker is assumed to be pre-installed as part of the k8s install process
    sudo yum -y update
    sudo rpm -Fvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    sudo yum install -y wget git jq bind-utils
  fi

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Install latest docker-compose"
    # Required, to use docker compose version 3.2 templates
    # Per https://docs.docker.com/compose/install/#install-compose
    # Current version is listed at https://github.com/docker/compose/releases
    sudo curl -L -o /usr/local/bin/docker-compose \
    "https://github.com/docker/compose/releases/download/1.23.1/docker-compose-$(uname -s)-$(uname -m)"
    sudo chmod +x /usr/local/bin/docker-compose
  fi
}

function clean_env() {
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Stop any running Acumos core docker-based components"
    sudo bash docker-compose.sh down
  else
    if [[ "$K8S_DIST" == "openshift" ]]; then
      echo "Delete project $ACUMOS_NAMESPACE"
      oc delete project $ACUMOS_NAMESPACE
      while oc project $ACUMOS_NAMESPACE; do
        echo "Waiting 10 seconds for project acumos to be deleted"
        sleep 10
      done
    else
      echo "Delete namespace $ACUMOS_NAMESPACE"
      kubectl delete namespace $ACUMOS_NAMESPACE
      while kubectl get namespace $ACUMOS_NAMESPACE; do
        echo "Waiting 10 seconds for namespace $ACUMOS_NAMESPACE to be deleted"
        sleep 10
      done
    fi
  fi
}

function prepare_env() {
  # TODO: redeploy without deleting all services first
  clean_env
  log "Create PV for logs"
  bash setup-pv.sh setup pv logs $ACUMOS_NAMESPACE $ACUMOS_LOGS_PV_SIZE "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"

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
  elif [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
    bash setup-pv.sh setup pv certs $ACUMOS_NAMESPACE $ACUMOS_CERTS_PV_SIZE \
      "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
  fi
}

function docker_login() {
  wait_until_success \
    "sudo docker login $1 -u $ACUMOS_PROJECT_NEXUS_USERNAME -p $ACUMOS_PROJECT_NEXUS_PASSWORD"
}

function setup_acumos() {
  trap 'fail' ERR
  log "Login to LF Nexus Docker repos, for Acumos project images"
  docker_login https://nexus3.acumos.org:10004
  docker_login https://nexus3.acumos.org:10003
  docker_login https://nexus3.acumos.org:10002

  if [[ "$HOST_OS" == "ubuntu" ]]; then sudo chown -R $USER:$USER $HOME/.docker; fi

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    if [[ "$ACUMOS_DEPLOY_KONG" != "true" ]]; then
      log "Update Portal-FE and Onboarding to use NodePorts range ports"
      export ACUMOS_PORTAL_FE_PORT=$ACUMOS_PORTAL_FE_NODEPORT
      sed -i -- "s/ACUMOS_PORTAL_FE_PORT=$ACUMOS_PORTAL_FE_PORT/ACUMOS_PORTAL_FE_PORT=$ACUMOS_PORTAL_FE_NODEPORT/" acumos-env.sh
      export ACUMOS_ONBOARDING_PORT=$ACUMOS_ONBOARDING_NODEPORT
      sed -i -- "s/ACUMOS_ONBOARDING_PORT=$ACUMOS_ONBOARDING_PORT/ACUMOS_ONBOARDING_PORT=$ACUMOS_ONBOARDING_NODEPORT/" acumos-env.sh
      sed -i -- 's~https://${ACUMOS_DOMAIN}:${ACUMOS_KONG_PROXY_SSL_PORT}~http://${ACUMOS_DOMAIN}:${ACUMOS_ONBOARDING_NODEPORT}~g' \
        docker/acumos/portal-be.yml
    fi

    log "Deploy Acumos core docker-based components"
    sudo bash docker-compose.sh up -d --build
    cd docker-proxy; source setup-docker-proxy.sh; cd ..
  else
    if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
      # Can't recreate PVCs if redeploying since data will still exist there
      log "Create PVCs in namespace $ACUMOS_NAMESPACE"
      source setup-pv.sh setup pvc logs $ACUMOS_NAMESPACE $ACUMOS_LOGS_PV_SIZE

      if [[ $(kubectl get secret -n $ACUMOS_NAMESPACE acumos-registry) ]]; then
        log "Deleting k8s secret acumos-registry, prior to recreating it"
        kubectl delete secret -n $ACUMOS_NAMESPACE acumos-registry
      fi

      log "Create k8s secret for image pulling from docker"
      if [[ "$HOST_OS" == "ubuntu" ]]; then
        b64=$(cat $HOME/.docker/config.json | base64 -w 0)
      else
        b64=$(sudo cat /root/.docker/config.json | base64 -w 0)
      fi
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

    if [[ "$ACUMOS_DEPLOY_KONG" != "true" ]]; then
      log "Update Portal-FE and Onboarding to provide NodePorts"
      sed -i -- 's/type: ClusterIP/type: NodePort/' deploy/portal-fe-service.yaml
      sed -i -- "/portal-fe-port/a\ \ \ \ nodePort: $ACUMOS_PORTAL_FE_NODEPORT" \
        deploy/portal-fe-service.yaml
      sed -i -- 's/type: ClusterIP/type: NodePort/' deploy/onboarding-service.yaml
      sed -i -- "/onboarding-port/a\ \ \ \ nodePort: $ACUMOS_ONBOARDING_NODEPORT" \
        deploy/onboarding-service.yaml
      sed -i -- 's~https://<ACUMOS_DOMAIN>:<ACUMOS_KONG_PROXY_SSL_PORT>~http://<ACUMOS_DOMAIN>:<ACUMOS_ONBOARDING_NODEPORT>~g' \
        deploy/portal-be-deployment.yaml
    fi

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
    cd docker-proxy; source setup-docker-proxy.sh; cd ..

    log "Wait for all Acumos core component pods to be Running"
    log "Wait for all elk-stack pods to be Running"
    apps="azure-client cms cds dsce federation kubernetes-client msg onboarding \
      portal-be portal-fe"
    for app in $apps; do
      wait_running $app
    done
  fi

  log "Customize aio-cms-host.yaml"
  sed -i -- "s~<ACUMOS_DOMAIN>~$ACUMOS_DOMAIN~g" aio-cms-host.yaml
}

function setup_federation() {
  trap 'fail' ERR
  log "Create 'self' peer entry (required) via CDS API"
  wait_until_success \
    "curl -s -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/peer"
  curl -s -o $HOME/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -X POST http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/peer -H "accept: */*" -H "Content-Type: application/json" -d "{ \"name\":\"$ACUMOS_DOMAIN\", \"self\": true, \"local\": false, \"contact1\": \"$ACUMOS_ADMIN_EMAIL\", \"subjectName\": \"$ACUMOS_DOMAIN\", \"apiUrl\": \"https://$ACUMOS_DOMAIN:$ACUMOS_FEDERATION_PORT\",  \"statusCode\": \"AC\", \"validationStatusCode\": \"PS\" }"
  if [[ "$(jq -r '.created' $HOME/json)" == "null" ]]; then
    cat $HOME/json
    fail "Peer entry creation failed"
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
sed -i -- "s/DEPLOY_RESULT=.*/DEPLOY_RESULT=/" acumos-env.sh
sed -i -- "s/FAIL_REASON=.*/FAIL_REASON=/" acumos-env.sh
update_env AIO_ROOT $WORK_DIR
update_env DEPLOYED_UNDER $1
update_env ACUMOS_DOMAIN $2
update_env K8S_DIST $3

if [[ "$ACUMOS_HOST" == "" ]]; then
  log "Determining host IP address for $ACUMOS_DOMAIN"
  if [[ $(host $ACUMOS_DOMAIN | grep -c 'not found') -eq 0 ]]; then
    update_env ACUMOS_HOST $(host $ACUMOS_DOMAIN | head -1 | cut -d ' ' -f 4)
  elif [[ $(grep -c -P " $ACUMOS_DOMAIN( |$)" /etc/hosts) -gt 0 ]]; then
    update_env ACUMOS_HOST $(grep -P "$ACUMOS_DOMAIN( |$)" /etc/hosts | cut -d ' ' -f 1)
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

if [[ "$2" == "openshift" ]]; then
  k8s_cmd=oc
else
  k8s_cmd=kubectl
fi

update_env ACUMOS_CDS_PASSWORD $(uuidgen)
update_env ACUMOS_NEXUS_RO_USER_PASSWORD $(uuidgen)
update_env ACUMOS_NEXUS_RW_USER_PASSWORD $(uuidgen)
update_env ACUMOS_DOCKER_REGISTRY_PASSWORD $ACUMOS_NEXUS_RW_USER_PASSWORD
update_env ACUMOS_DOCKER_PROXY_USERNAME $(uuidgen)
update_env ACUMOS_DOCKER_PROXY_PASSWORD $(uuidgen)

log "Apply environment customizations to unset values in acumos-env.sh"
source acumos-env.sh

if [[ -e mariadb-env.sh ]]; then
  source mariadb-env.sh
  export ACUMOS_DEPLOY_MARIADB=false
  sed -i -- "s/ACUMOS_DEPLOY_MARIADB=.*/ACUMOS_DEPLOY_MARIADB=$ACUMOS_DEPLOY_MARIADB/" acumos-env.sh
  export ACUMOS_SETUP_DB=false
  sed -i -- "s/ACUMOS_SETUP_DB=.*/ACUMOS_SETUP_DB=$ACUMOS_SETUP_DB/" acumos-env.sh
fi

if [[ "$ACUMOS_SETUP_PREREQS" == "true" ]]; then
  setup_prereqs
  export ACUMOS_SETUP_PREREQS=false
  sed -i -- "s/ACUMOS_SETUP_PREREQS=.*/ACUMOS_SETUP_PREREQS=$ACUMOS_SETUP_PREREQS/" acumos-env.sh
fi

prepare_env
source setup-keystore.sh

if [[ "$ACUMOS_DEPLOY_DOCKER" == "true" ]]; then
  cd docker-engine; source setup-docker-engine.sh; cd ..
fi

if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" && "$ACUMOS_DEPLOY_MARIADB" == "true" ]]; then
  cd mariadb; source setup-mariadb.sh; cd ..
fi

if [[ "$ACUMOS_SETUP_DB" == "true" ]]; then
  source setup-acumosdb.sh
fi

setup_acumos

if [[ "$ACUMOS_DEPLOY_KONG" == "true" ]]; then
  cd kong; source setup-kong.sh; cd ..
fi

if [[ "$ACUMOS_DEPLOY_NEXUS" == "true" ]]; then
  cd nexus; source setup-nexus.sh; cd ..
fi

if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  setup_federation
fi

if [[ "$ACUMOS_DEPLOY_ELK" == "true" ]]; then
  cd elk-stack
  sed -i -- "s/ACUMOS_ELK_DOMAIN=.*/ACUMOS_ELK_DOMAIN=$ACUMOS_DOMAIN/" acumos-env.sh
  sed -i -- "s/ACUMOS_ELK_HOST=.*/ACUMOS_ELK_HOST=$ACUMOS_HOST/" acumos-env.sh
  sed -i -- "s/ACUMOS_NAMESPACE=.*/ACUMOS_NAMESPACE=$ACUMOS_NAMESPACE/" acumos-env.sh
  source setup-elk.sh
  cd ..
fi

set +x
save_logs

log "Deploy is complete."
echo "Component details and stdout logs up to this point have been saved at"
echo "/tmp/acumos/debug, e.g. for debugging or if you are really bored."
echo "You can access the Acumos portal and other services at the URLs below,"
echo "assuming hostname \"$ACUMOS_DOMAIN\" is resolvable from your workstation:"
if [[ "$ACUMOS_DEPLOY_KONG" == "true" ]]; then
  portal_base=https://$ACUMOS_DOMAIN:$ACUMOS_KONG_PROXY_SSL_PORT
  onboarding_base=$portal_base
else
  portal_base=http://$ACUMOS_DOMAIN:$ACUMOS_PORTAL_FE_NODEPORT
  onboarding_base=http://$ACUMOS_DOMAIN:$ACUMOS_ONBOARDING_NODEPORT
fi
cat <<EOF >acumos.url
Portal: $portal_base
Onboarding API: $onboarding_base/onboarding-app
Common Data Service: http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/swagger-ui.html
Kibana: http://$ACUMOS_ELK_HOST:$ACUMOS_ELK_KIBANA_PORT/app/kibana
Hippo CMS: http://$ACUMOS_CMS_HOST:$ACUMOS_CMS_PORT/cms/console/?1&path=/
Nexus: http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT
Mariadb Admin: http://$ACUMOS_DOMAIN:$ACUMOS_MARIADB_ADMINER_PORT
Kong Admin: http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT
EOF
cat acumos.url
