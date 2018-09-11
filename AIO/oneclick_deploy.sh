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
# - Ubuntu Xenial server (Centos 7 support is planned!)
# - All hostnames specified in acumos-env.sh must be DNS-resolvable on all hosts
#   (entries in /etc/hosts or in an actual DNS server)
# - For deployments behind proxies, set HTTP_PROXY and HTTPS_PROXY in acumos-env.sh
# - For kubernetes based deplpyment: Kubernetes cluster deployed
# Usage:
# $ bash oneclick_deploy.sh <docker|k8s>
#   docker: install all components other than mariadb under docker-ce
#   k8s: install all components other than mariadb under kubernetes
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

set -x

trap 'fail' ERR

function fail() {
  log "$1"
  exit 1
}

function log() {
  set +x
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  echo; echo "$fname:$fline ($(date)) $1"
  set -x
}

function wait_dpkg() {
  # TODO: workaround for "E: Could not get lock /var/lib/dpkg/lock - open (11: Resource temporarily unavailable)"
  echo; echo "waiting for dpkg to be unlocked"
  while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
    sleep 1
  done
}

function setup_prereqs() {
  trap 'fail' ERR

  log "/etc/hosts customizations"
  # Ensure cluster hostname resolves inside the cluster
  if [[ $(grep -c $HOSTNAME /etc/hosts) -eq 0 ]]; then
    log "Add $HOSTNAME to /etc/hosts"
    # have to add "/sbin" to path of IP command for centos
    echo "$(/sbin/ip route get 8.8.8.8 | awk '{print $NF; exit}') $HOSTNAME" \
      | sudo tee -a /etc/hosts
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

  log "Basic prerequisites"

  wait_dpkg; sudo apt-get update
# TODO: fix need to skip upgrade as this sometimes updates the kube-system
# services and they then stay in "pending", blocking k8s-based deployment
#  wait_dpkg; sudo apt-get upgrade -y
  wait_dpkg; sudo apt-get install -y wget git jq

  if [[ "$DEPLOYED_UNDER" = "docker" ]]; then
    if [[ $(dpkg -l | grep -c docker-ce) -eq 0 ]]; then
      log "Install latest docker-ce"
      # Per https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/
      sudo apt-get remove -y docker docker-engine docker.io docker-ce
      sudo apt-get update
      sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
      sudo add-apt-repository "deb [arch=amd64] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
      sudo apt-get update
      sudo apt-get install -y docker-ce
    fi

    if [[ $(dpkg -l | grep -c docker-compose) -eq 0 ]]; then
      log "Install latest docker-compose"
      sudo apt-get install -y docker-compose
    fi

    log "Enable docker API"
    if [[ $(grep -c "\-H tcp://0.0.0.0:$ACUMOS_DOCKER_API_PORT" /lib/systemd/system/docker.service) -eq 0 ]]; then
      sudo sed -i -- "s~ExecStart=/usr/bin/dockerd -H fd://~ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:$ACUMOS_DOCKER_API_PORT~" /lib/systemd/system/docker.service
    fi

    log "Block host-external access to docker API"
    if [[ $(sudo iptables -S | grep -c '172.18.0.0/16 .* 2375') -eq 0 ]]; then
      sudo iptables -A INPUT -p tcp --dport 2375 ! -s 172.18.0.0/16 -j DROP
    fi
    if [[ $(sudo iptables -S | grep -c '127.0.0.1/32 .* 2375') -eq 0 ]]; then
      sudo iptables -I INPUT -s localhost -p tcp -m tcp --dport 2375 -j ACCEPT
    fi
    host_ip=$(/sbin/ip route get 8.8.8.8 | awk '{print $NF; exit}')
    if [[ $(sudo iptables -S | grep -c "$host_ip .* 2375") -eq 0 ]]; then
      sudo iptables -I INPUT -s $host_ip -p tcp -m tcp --dport 2375 -j ACCEPT
    fi

    log "Enable non-secure docker repositories"
    cat << EOF | sudo tee /etc/docker/daemon.json
{
  "insecure-registries": [
    "$ACUMOS_NEXUS_HOST:$ACUMOS_DOCKER_MODEL_PORT"
  ],
  "disable-legacy-registry": true
}
EOF

    sudo systemctl daemon-reload
    sudo service docker restart

    if [[ $(sudo docker volume ls | grep -c acumos-logs) -eq 0 ]]; then
      log "Create docker volumes for Acumos docker-based components"
      while ! curl http://$ACUMOS_DOCKER_API_HOST:$ACUMOS_DOCKER_API_PORT ; do
        log "waiting 30 seconds for docker daemon to be ready"
        sleep 30
      done
      sudo docker volume create kong-db
      sudo docker volume create acumos-logs
      sudo docker volume create acumos-output
      sudo docker volume create acumosWebOnboarding
      sudo docker volume create nexus-data
    fi
  fi

  if [[ ! -d /var/acumos ]]; then
    sudo mkdir -p /var/acumos
    sudo chown $USER:$USER /var/acumos
    mkdir /var/acumos/certs

    if [[ "$DEPLOYED_UNDER" = "k8s" ]]; then
      log "Create local shared folders for Acumos k8s-based components"
      mkdir -p /var/acumos/logs
      mkdir /var/acumos/output
      mkdir /var/acumos/WebOnboarding
      mkdir /var/acumos/kong-db
      mkdir /var/acumos/nexus-data
      sudo chown -R 200 /var/acumos/nexus-data
    fi
  fi
}

function setup_mariadb() {
  trap 'fail' ERR
  log "Installing MariaDB 10.2"
  # default version
  MARIADB_VERSION='10.2'
  # May need to update to another mirror if you encounter issues
  # See https://downloads.mariadb.org/mariadb/repositories/#mirror=accretive&distro=Ubuntu
  MARIADB_REPO='deb [arch=amd64,i386,ppc64el] http://sfo1.mirrors.digitalocean.com/mariadb/repo/10.2/ubuntu xenial main'

  log "Import mariadb repo key"
  sudo apt-get install software-properties-common -y
  sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
  sudo add-apt-repository "$MARIADB_REPO"
  sudo apt-get update -y

  log "Install MariaDB without password prompt"
  sudo debconf-set-selections <<< "mariadb-server-$MARIADB_VERSION mysql-server/root_password password $ACUMOS_MARIADB_PASSWORD"
  sudo debconf-set-selections <<< "mariadb-server-$MARIADB_VERSION mysql-server/root_password_again password $ACUMOS_MARIADB_PASSWORD"

  log "Install MariaDB"
  sudo apt-get install -y -q mariadb-server-$MARIADB_VERSION
  sudo systemctl daemon-reload

  log "Make MariaDB connectable from outside"
  sudo sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/my.cnf

  sudo sed -i 's/^\!includedir.*//' /etc/mysql/my.cnf
  cat << EOF | sudo tee -a /etc/mysql/my.cnf
# Added to use lower case for all tablenames.
[mariadb-10.2]
lower_case_table_names=1
!includedir /etc/mysql/mariadb.conf.d/
EOF

  sudo service mysql restart
  log "Secure mysql installation"
  mysql --user=root --password=$ACUMOS_MARIADB_PASSWORD -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1','::1'); DELETE FROM mysql.user WHERE User=''; DELETE FROM mysql.db WHERE Db='test' OR Db='test_%'; FLUSH PRIVILEGES;"
}

function setup_acumosdb() {
  trap 'fail' ERR
  log "Setup Acumos databases"
  if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
    log "Create myqsl user acumos_opr"
    mysql --user=root --password=$ACUMOS_MARIADB_PASSWORD -e "CREATE USER 'acumos_opr'@'%' IDENTIFIED BY \"$ACUMOS_MARIADB_USER_PASSWORD\";"

    log "Setup database $ACUMOS_CDS_DB"
    mysql --user=root --password=$ACUMOS_MARIADB_PASSWORD -e "CREATE DATABASE $ACUMOS_CDS_DB; USE $ACUMOS_CDS_DB; GRANT ALL PRIVILEGES ON $ACUMOS_CDS_DB.* TO 'acumos_opr'@'%' IDENTIFIED BY \"$ACUMOS_MARIADB_USER_PASSWORD\";"

    log "Retrieve and customize database script for CDS version $ACUMOS_CDS_VERSION"
    if [[ $(ls cmn-data-svc-ddl-dml-mysql*) != "" ]]; then rm cmn-data-svc-ddl-dml-mysql*; fi
    wget https://raw.githubusercontent.com/acumos/common-dataservice/master/cmn-data-svc-server/db-scripts/cmn-data-svc-ddl-dml-mysql-$ACUMOS_CDS_VERSION.sql
    sed -i -- "1s/^/use $ACUMOS_CDS_DB;\n/" cmn-data-svc-ddl-dml-mysql-$ACUMOS_CDS_VERSION.sql
    mysql --user=acumos_opr --password=$ACUMOS_MARIADB_USER_PASSWORD < cmn-data-svc-ddl-dml-mysql-$ACUMOS_CDS_VERSION.sql

    log "Setup database 'acumos_cms'"
    mysql --user=root --password=$ACUMOS_MARIADB_PASSWORD -e "CREATE DATABASE acumos_cms; USE acumos_cms; GRANT ALL PRIVILEGES ON acumos_cms.* TO 'acumos_opr'@'%' IDENTIFIED BY \"$ACUMOS_MARIADB_USER_PASSWORD\";"
  else
    if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" != "$ACUMOS_CDS_VERSION" ]]; then
      log "Upgrading database script for from CDS version $ACUMOS_CDS_PREVIOUS_VERSION to $ACUMOS_CDS_VERSION"
      upgrade="cds-mysql-upgrade-${ACUMOS_CDS_PREVIOUS_VERSION}-to-${ACUMOS_CDS_VERSION}.sql"
      if [[ $(ls ${upgrade}*) != "" ]]; then rm ${upgrade}*; fi
      wget https://raw.githubusercontent.com/acumos/common-dataservice/master/cmn-data-svc-server/db-scripts/$upgrade
      sed -i -- "1s/^/use $ACUMOS_CDS_DB;\n/" $upgrade
      mysql --user=acumos_opr --password=$ACUMOS_MARIADB_USER_PASSWORD < $upgrade
    fi
  fi
}

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
  curl -v -u admin:admin123 -H "Content-Type: application/json" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script/ -d @nexus-script.json
  curl -v -X POST -u admin:admin123 -H "Content-Type: text/plain" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script/$1/run
}

function setup_nexus() {
  trap 'fail' ERR
  # Add -m 10 since for some reason curl seems to hang waiting for a response
  while ! curl -v -m 10 -u $ACUMOS_NEXUS_ADMIN_USERNAME:$ACUMOS_NEXUS_ADMIN_PASSWORD http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script ; do
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
  "content": "security.addRole(\"$ACUMOS_RO_USER\", \"$ACUMOS_RO_USER\", \"Read Only\", [\"nx-search-read\", \"nx-repository-view-*-*-read\", \"nx-repository-view-*-*-browse\"], []); security.addRole(\"$ACUMOS_RW_USER\", \"$ACUMOS_RW_USER\", \"Read Write\", [\"nx-search-read\", \"nx-repository-view-*-*-read\", \"nx-repository-view-*-*-browse\", \"nx-repository-view-*-*-add\", \"nx-repository-view-*-*-edit\", \"nx-apikey-all\"], []); security.addUser(\"$ACUMOS_RO_USER\", \"Acumos\", \"Read Only\", \"acumos@example.com\", true, \"$ACUMOS_RO_USER_PASSWORD\", [\"$ACUMOS_RO_USER\"]); security.addUser(\"$ACUMOS_RW_USER\", \"Acumos\", \"Read Write\", \"acumos@example.com\", true, \"$ACUMOS_RW_USER_PASSWORD\", [\"$ACUMOS_RW_USER\"]);"
}
EOF
  curl -v -u admin:admin123 -H "Content-Type: application/json" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script/ -d @nexus-script.json
  # TODO: verify script creation
  curl -v -X POST -u admin:admin123 -H "Content-Type: text/plain" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script/add-roles-users/run

  log "Show nexus users"
  cat <<EOF >nexus-script.json
{
  "name": "list-users",
  "type": "groovy",
  "content": "import groovy.json.JsonOutput; import org.sonatype.nexus.security.user.User; users = security.getSecuritySystem().listUsers(); size = users.size(); log.info(\"User count: $size\"); return JsonOutput.toJson(users)"
}
EOF
  curl -v -u admin:admin123 -H "Content-Type: application/json" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script/ -d @nexus-script.json
  curl -v -X POST -u admin:admin123 -H "Content-Type: text/plain" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script/list-users/run
}

function docker_login() {
  while ! sudo docker login $1 -u $ACUMOS_PROJECT_NEXUS_USERNAME -p $ACUMOS_PROJECT_NEXUS_PASSWORD ; do
    log "Docker login failed at $1, trying again"
  done
}

function setup_elk() {
  if [[ "$DEPLOYED_UNDER" = "docker" ]]; then
		if [[ $(sudo docker volume ls | grep -c acumos-esdata) -eq 0 ]]; then
      log "Create docker volume for ElasticSearch persistent data"
		  sudo docker volume create acumos-esdata
		fi
  else
    log "Create local shared folder for ElasticSearch persistent data"
    mkdir -p /var/acumos/esdata
  fi

  log "Prepare ELK stack component configs for AIO deploy"
  if [[ -d platform-oam ]]; then rm -rf platform-oam; fi
  git clone https://gerrit.acumos.org/r/platform-oam
  cp -r platform-oam/elk-stack/elasticsearch /var/acumos/.
  cat <<EOF >/var/acumos/elasticsearch/config/jvm.options
-Xmx${ACUMOS_ELK_LS_JAVA_HEAP_MAX_SIZE}
-Xms${ACUMOS_ELK_LS_JAVA_HEAP_MIN_SIZE}
EOF
  log "Correct references to elasticsearch-service for AIO deploy"
  sed -i -- 's/elasticsearch:9200/elasticsearch-service:9200/g' \
    platform-oam/elk-stack/logstash/pipeline/logstash.conf
  sed -i -- 's/elasticsearch:9200/elasticsearch-service:9200/g' \
    platform-oam/elk-stack/kibana/config/kibana.yml
  log "Copy ELK stack component configs to /;var/acumos"
  cp -r platform-oam/elk-stack/kibana /var/acumos/.
  cp -r platform-oam/elk-stack/logstash /var/acumos/.
}

function setup_acumos() {
  trap 'fail' ERR
  log "Log into LF Nexus Docker repos"
  docker_login https://nexus3.acumos.org:10004
  docker_login https://nexus3.acumos.org:10003
  docker_login https://nexus3.acumos.org:10002
  sudo chown -R $USER:$USER ~/.docker

  setup_elk

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    log "Deploy Acumos docker-based components"
    sudo bash docker-compose.sh build
    log "Start ELK stack first and wait for ElasticSearch to be active"
    # metricbeat will exit if ElasticSearch isn't listening on its exposed port
    sudo bash docker-compose.sh up -d \
      elasticsearch-service logstash-service kibana-service
    url=http://$ACUMOS_HOST:$ACUMOS_ELK_ELASTICSEARCH_PORT
    while ! curl $url ; do
      log "ElasticSearch is not yet responding at $url, waiting 10 seconds"
      sleep 10
    done
    sudo bash docker-compose.sh up -d \
      elasticsearch-service logstash-service kibana-service
    sudo bash docker-compose.sh up -d kong-service nexus-service 
    sudo bash docker-compose.sh up -d \
      cms-service azure-client-service cds-service dsce-service \
      federation-service onboarding-service portal-be-service portal-fe-service
    sudo bash docker-compose.sh up -d \
      metricbeat-service filebeat-service
  else
    if [[ $(kubectl get namespaces | grep -c 'acumos ') == 1 ]]; then
      echo "Stop any running Acumos component services under kubernetes"
      kubectl delete service -n acumos azure-client-service cds-service cms-service\
        filebeat-service onboarding-service portal-be-service portal-fe-service \
        dsce-service federation-service kong-service nexus-service

      echo "Stop any running Acumos component deployments under kubernetes"
      kubectl delete deployment -n acumos azure-client cds cms filebeat onboarding\
        portal-be portal-fe dsce federation kong nexus

      echo "Delete acumos image pull secret from kubernetes"
      kubectl delete secret -n acumos acumos-registry

      echo "Delete namespace acumos from kubernetes"
      kubectl delete namespace acumos
      while kubectl get namespace acumos; do
        echo "Waiting 10 seconds for namespace acumos to be deleted"
        sleep 10
      done
    fi

    log "Create namespace acumos"
    while ! kubectl create namespace acumos; do
      log "kubectl API is not yet ready ... waiting 10 seconds"
      sleep 10
    done

    log "Create k8s secret for image pulling from docker"
    b64=$(cat ~/.docker/config.json | base64 -w 0)
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

    kubectl create -f acumos-registry.yaml

    log "Deploy Acumos kubernetes-based components"
    log "Set variable values in k8s templates"
    depvars="ACUMOS_HOST ACUMOS_DOMAIN ACUMOS_MARIADB_HOST ACUMOS_MARIADB_PORT ACUMOS_MARIADB_USER_PASSWORD ACUMOS_NEXUS_API_PORT ACUMOS_NEXUS_HOST ACUMOS_RW_USER ACUMOS_RO_USER ACUMOS_RW_USER_PASSWORD ACUMOS_RO_USER_PASSWORD ACUMOS_DOCKER_API_HOST ACUMOS_DOCKER_API_PORT ACUMOS_DOCKER_MODEL_PORT ACUMOS_KONG_DB_PORT ACUMOS_KONG_PROXY_PORT ACUMOS_KONG_PROXY_SSL_PORT ACUMOS_KONG_ADMIN_PORT ACUMOS_KONG_ADMIN_SSL_PORT ACUMOS_DOCKER_API_PORT ACUMOS_PROJECT_NEXUS_USERNAME ACUMOS_PROJECT_NEXUS_PASSWORD ACUMOS_ELK_ELASTICSEARCH_HOST ACUMOS_ELK_ELASTICSEARCH_PORT ACUMOS_ELK_NODEPORT ACUMOS_ELK_LOGSTASH_HOST ACUMOS_ELK_LOGSTASH_PORT ACUMOS_ELK_KIBANA_PORT ACUMOS_ELK_KIBANA_NODEPORT ACUMOS_ELK_ES_JAVA_HEAP_MIN_SIZE ACUMOS_ELK_ES_JAVA_HEAP_MAX_SIZE ACUMOS_ELK_LS_JAVA_HEAP_MIN_SIZE ACUMOS_ELK_LS_JAVA_HEAP_MAX_SIZE ACUMOS_METRICBEAT_PORT"

    compvars="ACUMOS_AZURE_CLIENT_PORT ACUMOS_CDS_PORT ACUMOS_CDS_DB ACUMOS_CDS_PASSWORD ACUMOS_CDS_USER ACUMOS_CMS_PORT ACUMOS_DSCE_PORT ACUMOS_FEDERATION_PORT ACUMOS_FILEBEAT_PORT  ACUMOS_MICROSERVICE_GENERATION_PORT ACUMOS_ONBOARDING_PORT ACUMOS_PORTAL_BE_PORT ACUMOS_PORTAL_FE_PORT ACUMOS_KEYPASS ACUMOS_DATA_BROKER_INTERNAL_PORT ACUMOS_DATA_BROKER_PORT ACUMOS_DEPLOYED_SOLUTION_PORT ACUMOS_DEPLOYED_VM_PASSWORD ACUMOS_DEPLOYED_VM_USER ACUMOS_PROBE_PORT ACUMOS_OPERATOR_ID HTTP_PROXY HTTPS_PROXY"
    set +x
    mkdir -p ~/deploy/kubernetes
    cp -r kubernetes/* ~/deploy/kubernetes/.
    vs="$depvars $compvars"
    for f in  ~/deploy/kubernetes/service/*.yaml  ~/deploy/kubernetes/deployment/*.yaml; do
      for v in $vs ; do
        eval vv=\$$v
        sed -i -- "s/<$v>/$vv/g" $f
      done
    done
    set -x

    log "Set image references in k8s templates"
    sed -i -- "s~<AZURE_CLIENT_IMAGE>~$AZURE_CLIENT_IMAGE~g"  ~/deploy/kubernetes/deployment/azure-client-deployment.yaml
    sed -i -- "s~<BLUEPRINT_ORCHESTRATOR_IMAGE>~$BLUEPRINT_ORCHESTRATOR_IMAGE~g"  ~/deploy/kubernetes/deployment/azure-client-deployment.yaml
    sed -i -- "s~<PORTAL_CMS_IMAGE>~$PORTAL_CMS_IMAGE~g"  ~/deploy/kubernetes/deployment/cms-deployment.yaml
    sed -i -- "s~<COMMON_DATASERVICE_IMAGE>~$COMMON_DATASERVICE_IMAGE~g"  ~/deploy/kubernetes/deployment/common-data-svc-deployment.yaml
    sed -i -- "s~<DESIGNSTUDIO_IMAGE>~$DESIGNSTUDIO_IMAGE~g"  ~/deploy/kubernetes/deployment/dsce-deployment.yaml
    sed -i -- "s~<DATABROKER_ZIPBROKER_IMAGE>~$DATABROKER_ZIPBROKER_IMAGE~g"  ~/deploy/kubernetes/deployment/dsce-deployment.yaml
    sed -i -- "s~<DATABROKER_CSVBROKER_IMAGE>~$DATABROKER_CSVBROKER_IMAGE~g"  ~/deploy/kubernetes/deployment/dsce-deployment.yaml
    sed -i -- "s~<FEDERATION_IMAGE>~$FEDERATION_IMAGE~g"  ~/deploy/kubernetes/deployment/federation-deployment.yaml
    sed -i -- "s~<FILEBEAT_IMAGE>~$FILEBEAT_IMAGE~g"  ~/deploy/kubernetes/deployment/filebeat-deployment.yaml
    sed -i -- "s~<MICROSERVICE_GENERATION_IMAGE>~$MICROSERVICE_GENERATION_IMAGE~g"  ~/deploy/kubernetes/deployment/microservice-generation-deployment.yaml
    sed -i -- "s~<ONBOARDING_IMAGE>~$ONBOARDING_IMAGE~g"  ~/deploy/kubernetes/deployment/onboarding-deployment.yaml
    sed -i -- "s~<ONBOARDING_BASE_IMAGE>~$ONBOARDING_BASE_IMAGE~g"  ~/deploy/kubernetes/deployment/onboarding-deployment.yaml
    sed -i -- "s~<PORTAL_BE_IMAGE>~$PORTAL_BE_IMAGE~g"  ~/deploy/kubernetes/deployment/portal-be-deployment.yaml
    sed -i -- "s~<PORTAL_FE_IMAGE>~$PORTAL_FE_IMAGE~g"  ~/deploy/kubernetes/deployment/portal-fe-deployment.yaml
    sed -i -- "s~<ELASTICSEARCH_IMAGE>~$ELASTICSEARCH_IMAGE~g"  ~/deploy/kubernetes/deployment/elk-deployment.yaml
    sed -i -- "s~<LOGSTASH_IMAGE>~$LOGSTASH_IMAGE~g"  ~/deploy/kubernetes/deployment/elk-deployment.yaml
    sed -i -- "s~<KIBANA_IMAGE>~$KIBANA_IMAGE~g"  ~/deploy/kubernetes/deployment/elk-deployment.yaml
    sed -i -- "s~<FILEBEAT_IMAGE>~$FILEBEAT_IMAGE~g"  ~/deploy/kubernetes/deployment/filebeat-deployment.yaml
    sed -i -- "s~<METRICBEAT_IMAGE>~$METRICBEAT_IMAGE~g"  ~/deploy/kubernetes/deployment/metricbeat-deployment.yaml

    log "Deploy the k8s based components"
    # Create services first... see https://github.com/kubernetes/kubernetes/issues/16448
    for f in  ~/deploy/kubernetes/service/*.yaml ; do
      log "Creating service from $f"
      kubectl create -f $f
    done
    for f in  ~/deploy/kubernetes/deployment/*.yaml ; do
      log "Creating deployment from $f"
      kubectl create -f $f
    done
  fi
}

# Setup server cert, key, and keystore for the Kong reverse proxy
# Currently the certs folder is also setup via docker-compose.yaml as a virtual
# folder for the federation-gateway, which currently does not support http
# access via the Kong proxy (only direct https access)
# TODO: federation-gateway support for access via HTTP from Kong reverse proxy
function setup_keystore() {
  trap 'fail' ERR
  log "Install keytool"
  sudo apt-get install -y openjdk-8-jre-headless

  log "Create self-signing CA"
  # Customize openssl.cnf as this is needed to set CN (vs command options below)
  sed -i -- "s/<acumos-domain>/$ACUMOS_DOMAIN/" openssl.cnf
  sed -i -- "s/<acumos-host>/$ACUMOS_HOST/" openssl.cnf

  openssl genrsa -des3 -out /var/acumos/certs/acumosCA.key -passout pass:$ACUMOS_KEYPASS 4096

  openssl req -x509 -new -nodes -key /var/acumos/certs/acumosCA.key -sha256 -days 1024 \
   -config openssl.cnf -out /var/acumos/certs/acumosCA.crt -passin pass:$ACUMOS_KEYPASS \
   -subj "/C=US/ST=Unspecified/L=Unspecified/O=Acumos/OU=Acumos/CN=$ACUMOS_DOMAIN"

  log "Create server certificate key"ACUMOS-1598
  openssl genrsa -out /var/acumos/certs/acumos.key -passout pass:$ACUMOS_KEYPASS 4096

  log "Create a certificate signing request for the server cert"
  # ACUMOS_HOST is used as CN since it's assumed that the client's hostname
  # is not resolvable via DNS for this AIO deploy
  openssl req -new -key /var/acumos/certs/acumos.key -passin pass:$ACUMOS_KEYPASS \
    -out /var/acumos/certs/acumos.csr \
    -subj "/C=US/ST=Unspecified/L=Unspecified/O=Acumos/OU=Acumos/CN=$ACUMOS_DOMAIN"

  log "Sign the CSR with the acumos CA"
  openssl x509 -req -in /var/acumos/certs/acumos.csr -CA /var/acumos/certs/acumosCA.crt \
    -CAkey /var/acumos/certs/acumosCA.key -CAcreateserial -passin pass:$ACUMOS_KEYPASS \
    -extfile openssl.cnf -out /var/acumos/certs/acumos.crt -days 500 -sha256

  log "Create PKCS12 format keystore with acumos server cert"
  openssl pkcs12 -export -in /var/acumos/certs/acumos.crt -passin pass:$ACUMOS_KEYPASS \
    -inkey /var/acumos/certs/acumos.key -certfile /var/acumos/certs/acumos.crt \
    -out /var/acumos/certs/acumos_aio.p12 -passout pass:$ACUMOS_KEYPASS

  log "Create JKS format truststore with acumos CA cert"
  keytool -import -file /var/acumos/certs/acumosCA.crt -alias acumosCA -keypass $ACUMOS_KEYPASS \
    -keystore /var/acumos/certs/acumosTrustStore.jks -storepass $ACUMOS_KEYPASS -noprompt
}

function setup_reverse_proxy() {
  trap 'fail' ERR
  log "Verify kong admin API is ready"
  while ! curl http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/apis; do
    log "Kong admin API is not ready... waiting 10 seconds"
    sleep 10
  done

  log "Pass cert and key to Kong admin"
  curl -i -X POST http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/certificates \
    -F "cert=@/var/acumos/certs/acumos.crt" \
    -F "key=@/var/acumos/certs/acumos.key" \
    -F "snis=$ACUMOS_DOMAIN"

  log "Add proxy entries via Kong API"
#  curl -i -X POST \
#    --url http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/apis/ \
#    --data "https_only=true" \
#    --data "name=site" \
#    --data "upstream_url=http://$ACUMOS_CMS_HOST:$ACUMOS_CMS_PORT" \
#    --data "uris=/site" \
#    --data "strip_uri=false"
  curl -i -X POST \
    --url http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/apis/ \
    --data "https_only=true" \
    --data "name=root" \
    --data "upstream_url=http://portal-fe-service:$ACUMOS_PORTAL_FE_PORT" \
    --data "uris=/" \
    --data "strip_uri=false" \
    --data "upstream_connect_timeout=60000" \
    --data "upstream_read_timeout=60000" \
    --data "upstream_send_timeout=60000" \
    --data "retries=5"

  curl -i -X POST \
    --url http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/apis/ \
    --data "https_only=true" \
    --data "name=onboarding-app" \
    --data "upstream_url=http://onboarding-service:$ACUMOS_ONBOARDING_PORT" \
    --data "uris=/onboarding-app" \
    --data "strip_uri=false" \
    --data "upstream_connect_timeout=60000" \
    --data "upstream_read_timeout=600000" \
    --data "upstream_send_timeout=600000" \
    --data "retries=5"

  log "Dump of API endpoints as created"
  curl http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/apis/

  log "Add cert as CA to docker /etc/docker/certs.d"
  # Required for docker daemon to accept the kong self-signed cert
  # Per https://docs.docker.com/registry/insecure/#use-self-signed-certificates
  sudo mkdir -p /etc/docker/certs.d/$ACUMOS_HOST
  sudo cp /var/acumos/certs/acumosCA.crt /etc/docker/certs.d/$ACUMOS_HOST/ca.crt
}

function setup_federation() {
  trap 'fail' ERR
  log "Create 'self' peer entry (required) via CDS API"
  while ! curl -s -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/peer ; do
    log "CDS API is not yet responding... waiting 10 seconds"
    sleep 10
  done
  curl -s -o ~/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -X POST http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/peer -H "accept: */*" -H "Content-Type: application/json" -d "{ \"name\":\"$ACUMOS_DOMAIN\", \"self\": true, \"local\": false, \"contact1\": \"admin@example.com\", \"subjectName\": \"$ACUMOS_DOMAIN\", \"apiUrl\": \"https://$ACUMOS_DOMAIN:$ACUMOS_FEDERATION_PORT\",  \"statusCode\": \"AC\", \"validationStatusCode\": \"PS\" }"
  created=$(jq -r '.created' ~/json)
  if [[ "$created" == "null" ]]; then
    cat ~/json
    fail "Peer entry creation failed"
  fi
}

export WORK_DIR=$(pwd)
log "Reset acumos-env.sh"
sed -i -- '/DEPLOYED_UNDER/d' acumos-env.sh

if [[ "$1" == "k8s" ]]; then DEPLOYED_UNDER=k8s
else DEPLOYED_UNDER=docker
fi
echo "DEPLOYED_UNDER=\"$DEPLOYED_UNDER\"" >>acumos-env.sh
echo "export DEPLOYED_UNDER" >>acumos-env.sh
source acumos-env.sh

# Create the following only if deploying with a new DB
if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  sed -i -- '/ACUMOS_CDS_PASSWORD/d' acumos-env.sh
  sed -i -- '/ACUMOS_KEYPASS/d' acumos-env.sh
  sed -i -- '/ACUMOS_MARIADB_PASSWORD/d' acumos-env.sh
  sed -i -- '/ACUMOS_MARIADB_USER_PASSWORD/d' acumos-env.sh
  sed -i -- '/ACUMOS_RO_USER_PASSWORD/d' acumos-env.sh
  sed -i -- '/ACUMOS_RW_USER_PASSWORD/d' acumos-env.sh
  ACUMOS_MARIADB_PASSWORD=$(uuidgen)
  echo "ACUMOS_MARIADB_PASSWORD=\"$ACUMOS_MARIADB_PASSWORD\"" >>acumos-env.sh
  echo "export ACUMOS_MARIADB_PASSWORD" >>acumos-env.sh
  ACUMOS_MARIADB_USER_PASSWORD=$(uuidgen)
  echo "ACUMOS_MARIADB_USER_PASSWORD=\"$ACUMOS_MARIADB_USER_PASSWORD\"" >>acumos-env.sh
  echo "export ACUMOS_MARIADB_USER_PASSWORD" >>acumos-env.sh

  ACUMOS_RO_USER_PASSWORD=$(uuidgen)
  echo "ACUMOS_RO_USER_PASSWORD=\"$ACUMOS_RO_USER_PASSWORD\"" >>acumos-env.sh
  echo "export ACUMOS_RO_USER_PASSWORD" >>acumos-env.sh
  ACUMOS_RW_USER_PASSWORD=$(uuidgen)
  echo "ACUMOS_RW_USER_PASSWORD=\"$ACUMOS_RW_USER_PASSWORD\"" >>acumos-env.sh
  echo "export ACUMOS_RW_USER_PASSWORD" >>acumos-env.sh
  ACUMOS_CDS_PASSWORD=$(uuidgen)
  echo "ACUMOS_CDS_PASSWORD=\"$ACUMOS_CDS_PASSWORD\"" >>acumos-env.sh
  echo "export ACUMOS_CDS_PASSWORD" >>acumos-env.sh
  ACUMOS_KEYPASS=$(uuidgen)
  echo "ACUMOS_KEYPASS=$ACUMOS_KEYPASS" >>acumos-env.sh
  echo "export ACUMOS_KEYPASS" >>acumos-env.sh
fi

source acumos-env.sh

if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  setup_prereqs
  setup_mariadb
  setup_keystore
fi
setup_acumosdb
setup_acumos
setup_reverse_proxy
if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  setup_nexus
  setup_federation
fi

log "Deploy is complete. You can access the portal at https://$ACUMOS_DOMAIN:$ACUMOS_KONG_PROXY_SSL_PORT (assuming you have added that hostname to your hosts file)"
