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
# Prerequisites:
# - Ubuntu Xenial (16.04), Bionic (18.04), or Centos 7 hosts
# - All hostnames specified in acumos-env.sh must be DNS-resolvable on all hosts
#   (entries in /etc/hosts or in an actual DNS server)
# - For deployments behind proxies, set HTTP_PROXY and HTTPS_PROXY in acumos-env.sh
# - For kubernetes based deplpyment: Kubernetes cluster deployed
# Usage:
# $ bash oneclick_deploy.sh <under> <k8sdist>
#   under: docker|k8s
#     docker: install all components other than mariadb under docker-ce
#     k8s: install all components other than mariadb under kubernetes
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
  if [[ $(grep -c -P " $HOSTNAME( |$)" /etc/hosts) -eq 0 ]]; then
    echo; echo "prereqs.sh: ($(date)) Add $HOSTNAME to /etc/hosts"
    # have to add "/sbin" to path of IP command for centos
    echo "$(/sbin/ip route get 8.8.8.8 | head -1 | sed 's/^.*src //' | awk '{print $1}') $HOSTNAME" \
      | sudo tee -a /etc/hosts
  fi

  if [[ $(grep -c -P " $ACUMOS_DOMAIN( |$)" /etc/hosts) -eq 0 ]]; then
    log "Add $ACUMOS_DOMAIN to /etc/hosts"
    echo "$ACUMOS_HOST $ACUMOS_DOMAIN" | sudo tee -a /etc/hosts
  fi
  log "/etc/hosts:"
  cat /etc/hosts

  # Add 'options ndots:5' to first resolve names using DNS search options
  if [[ $(grep -c 'options ndots:5' /etc/resolv.conf) -eq 0 ]]; then
    log "Add 'options ndots:5' to /etc/resolv.conf"
    echo "options ndots:5" | sudo tee -a /etc/resolv.conf
  fi
  log "/etc/resolv.conf:"
  cat /etc/resolv.conf

  # Per https://kubernetes.io/docs/setup/independent/install-kubeadm/
  log "Basic prerequisites"
  if [[ "$ACUMOS_HOST_OS" == "ubuntu" ]]; then
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
    log "Stop and remove services for all core components"
    for f in  deploy/*-service.yaml ; do
      stop_service $f
    done
    log "Stop and remove deployments for all core components"
    for f in  deploy/*-deployment.yaml ; do
      stop_deployment $f
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

  # Can't recreate PVs if redeploying since data will still exist there
  if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
    log "Create host folders for docker volumes and k8s PVs"
    bash setup-pv.sh setup pv logs $ACUMOS_LOGS_PV_SIZE "$USER:$USER"
    bash setup-pv.sh setup pv output $ACUMOS_OUTPUT_PV_SIZE "$USER:$USER"
    bash setup-pv.sh setup pv webonboarding $ACUMOS_WEBONBOARDING_PV_SIZE "$USER:$USER"
    bash setup-pv.sh setup pv certs $ACUMOS_CERTS_PV_SIZE "$USER:$USER"
  fi
}

function docker_login() {
  wait_until_success \
    "sudo docker login $1 -u $ACUMOS_PROJECT_NEXUS_USERNAME -p $ACUMOS_PROJECT_NEXUS_PASSWORD"
}

function setup_acumos() {
  trap 'fail' ERR
  log "Log into LF Nexus Docker repos"
  docker_login https://nexus3.acumos.org:10004
  docker_login https://nexus3.acumos.org:10003
  docker_login https://nexus3.acumos.org:10002
  if [[ "$ACUMOS_HOST_OS" == "ubuntu" ]]; then sudo chown -R $USER:$USER $HOME/.docker; fi

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
    cd docker-proxy; bash setup-docker-proxy.sh; cd ..
  else
    if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
      # Can't recreate PVCs if redeploying since data will still exist there
      log "Create PVCs in namespace $ACUMOS_NAMESPACE"
      bash setup-pv.sh setup pvc logs $ACUMOS_LOGS_PV_SIZE
      bash setup-pv.sh setup pvc output $ACUMOS_OUTPUT_PV_SIZE
      bash setup-pv.sh setup pvc webonboarding $ACUMOS_WEBONBOARDING_PV_SIZE
      bash setup-pv.sh setup pvc certs $ACUMOS_CERTS_PV_SIZE
      log "Create k8s secret for image pulling from docker"
      if [[ "$ACUMOS_HOST_OS" == "ubuntu" ]]; then b64=$(cat $HOME/.docker/config.json | base64 -w 0)
      else b64=$(sudo cat /root/.docker/config.json | base64 -w 0)
      fi
      cat <<EOF >acumos-registry.yaml
apiVersion: v1
kind: Secret
metadata:
  name: acumos-registry
  namespace: acumos
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
    cd docker-proxy; bash setup-docker-proxy.sh; cd ..

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

set -x
export WORK_DIR=$(pwd)
AIO_ROOT=$WORK_DIR
echo "export AIO_ROOT=$AIO_ROOT" >>acumos-env.sh

# This supports the option to clean and redeploy with under a different env,
# using the same customized acumos-env.sh file.
if [[ "$1" == "k8s" ]]; then DEPLOYED_UNDER=k8s
else DEPLOYED_UNDER=docker
fi
echo "export DEPLOYED_UNDER=$DEPLOYED_UNDER" >>acumos-env.sh

if [[ "$2" == "openshift" ]]; then
  K8S_DIST=openshift
  k8s_cmd=oc
else
  K8S_DIST=generic
  k8s_cmd=kubectl
fi
echo "export K8S_DIST=$K8S_DIST" >>acumos-env.sh

source acumos-env.sh
source utils.sh

update_env ACUMOS_CDS_PASSWORD "$ACUMOS_CDS_PASSWORD" $(uuidgen)
update_env ACUMOS_NEXUS_RO_USER_PASSWORD "$ACUMOS_NEXUS_RO_USER_PASSWORD" \
  $(uuidgen)
update_env ACUMOS_NEXUS_RW_USER_PASSWORD "$ACUMOS_NEXUS_RW_USER_PASSWORD" \
  $(uuidgen)
update_env ACUMOS_DOCKER_REGISTRY_PASSWORD "$ACUMOS_DOCKER_REGISTRY_PASSWORD" \
  $ACUMOS_NEXUS_RW_USER_PASSWORD
update_env ACUMOS_DOCKER_PROXY_USERNAME "$ACUMOS_DOCKER_PROXY_USERNAME" $(uuidgen)
update_env ACUMOS_DOCKER_PROXY_PASSWORD "$ACUMOS_DOCKER_PROXY_PASSWORD" $(uuidgen)

source $AIO_ROOT/acumos-env.sh

if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  setup_prereqs
fi

bash setup-keystore.sh
prepare_env

if [[ "$ACUMOS_DEPLOY_DOCKER" == "true" ]]; then
  cd docker-engine; bash setup-docker-engine.sh; cd ..
fi

if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" && "$ACUMOS_DEPLOY_MARIADB" == "true" ]]; then
  cd mariadb; bash setup-mariadb.sh; cd ..
fi

source acumos-env.sh
bash setup-acumosdb.sh
setup_acumos

if [[ "$ACUMOS_DEPLOY_KONG" == "true" ]]; then
  cd kong; bash setup-kong.sh; cd ..
fi

if [[ "$ACUMOS_DEPLOY_NEXUS" == "true" ]]; then
  cd nexus; bash setup-nexus.sh; cd ..
fi

if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  setup_federation
fi

if [[ "$ACUMOS_DEPLOY_ELK" == "true" ]]; then
  cd elk-stack; bash setup-elk.sh; cd ..
fi

set +x
save_logs
log "Current PV usage, in Kbytes"
sudo du -sbck /var/acumos/*

log "Deploy is complete."
echo "Component details and stdout logs up to this point have been saved at"
echo "/tmp/acumos/debug, e.g. for debugging or if you are really bored."
echo "You can monitor disk usage of the persistent volumes via the commannd:"
echo "sudo du -h -s /var/acumos/*"
sudo du -h -s /var/acumos/*
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
