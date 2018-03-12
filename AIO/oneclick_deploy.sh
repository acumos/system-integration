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
# What this is: All-in-One deployment of the Acumos platform.
# Prerequisites:
# - Ubuntu Xenial server (Centos 7 support is planned!)
# Usage:
# $ bash oneclick_deploy.sh
#

set -x

trap 'fail' ERR

function fail() {
  log $1
  exit 1
}

function log() {
  f=$(caller 0 | awk '{print $2}')
  l=$(caller 0 | awk '{print $1}')
  echo; echo "$f:$l ($(date)) $1"
}

function wait_dpkg() {
  # TODO: workaround for "E: Could not get lock /var/lib/dpkg/lock - open (11: Resource temporarily unavailable)"
  echo; echo "waiting for dpkg to be unlocked"
  while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
    sleep 1
  done
}

function setup_prereqs() {
  dist=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
  if [[ $(grep -c $HOSTNAME /etc/hosts) -eq 0 ]]; then
    echo; echo "prereqs.sh: ($(date)) Add $HOSTNAME to /etc/hosts"
    # have to add "/sbin" to path of IP command for centos
    echo "$(/sbin/ip route get 8.8.8.8 | awk '{print $NF; exit}') $HOSTNAME" \
      | sudo tee -a /etc/hosts
  fi

  log "Basic prerequisites"

  wait_dpkg; sudo apt-get update
  wait_dpkg; sudo apt-get upgrade -y
  wait_dpkg; sudo apt-get install -y wget git jq

  log "Install latest docker-ce"
  # Per https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/
  sudo apt-get remove -y docker docker-engine docker.io docker-ce
  sudo apt-get update
  sudo apt-get install -y \
    linux-image-extra-$(uname -r) \
    linux-image-extra-virtual
  sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-compose

  log "Enable docker remote API"
  sudo sed -i -- 's~ExecStart=/usr/bin/dockerd -H fd://~ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:4243~' /lib/systemd/system/docker.service
  log "Enable non-secure docker repositories"
cat << EOF | sudo tee /etc/docker/daemon.json
{
  "insecure-registries": [
    "nexus:$ACUMOS_DOCKER_MODEL_PORT", "nexus:$ACUMOS_DOCKER_PLATFORM_PORT", "nexus:$ACUMOS_MAVEN_MODEL_PORT"
  ],
  "disable-legacy-registry": true
}
EOF
  sudo systemctl daemon-reload
  sudo service docker restart

  log "Create Volumes for Acumos application"
  while ! curl http://$ACUMOS_DOCKER_API_HOST:4243 ; do
    log "waiting 30 seconds for docker daemon to be ready"
    sleep 30
  done
  sudo docker volume create acumos-logs
  sudo docker volume create acumos-output
  sudo docker volume create acumosWebOnboarding
  sudo docker volume create kong-db
}

function setup_mariadb() {
  log "Installing MariaDB 10.2"
  # default version
  MARIADB_VERSION='10.2'

  log "Import mariadb repo key"
  sudo apt-get install software-properties-common -y
  sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
  cat << 'EOF' | sudo tee /etc/apt/sources.list.d/mariadb.list
deb [arch=amd64,i386] http://mirror.jmu.edu/pub/mariadb/repo/10.2/ubuntu xenial main
deb-src http://mirror.jmu.edu/pub/mariadb/repo/10.2/ubuntu xenial main
EOF
  sudo apt-get update -y

  log "Install MariaDB without password prompt"
  sudo debconf-set-selections <<< "mariadb-server-$MARIADB_VERSION mysql-server/root_password password $MARIADB_PASSWORD"
  sudo debconf-set-selections <<< "mariadb-server-$MARIADB_VERSION mysql-server/root_password_again password $MARIADB_PASSWORD"

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
  mysql --user=root --password=$MARIADB_PASSWORD -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1','::1'); DELETE FROM mysql.user WHERE User=''; DELETE FROM mysql.db WHERE Db='test' OR Db='test_%'; FLUSH PRIVILEGES;"
}

function setup_acumosdb() {
  log "Setup Acumos databases"

  log "Create myqsl user acumos_opr"
  mysql --user=root --password=$MARIADB_PASSWORD -e "CREATE USER 'acumos_opr'@'%' IDENTIFIED BY \"$MARIADB_USER_PASSWORD\";"

  log "Setup database $ACUMOS_CDS_DB"
  mysql --user=root --password=$MARIADB_PASSWORD -e "CREATE DATABASE $ACUMOS_CDS_DB; USE $ACUMOS_CDS_DB; GRANT ALL PRIVILEGES ON $ACUMOS_CDS_DB.* TO 'acumos_opr'@'%' IDENTIFIED BY \"$MARIADB_USER_PASSWORD\";"
  # Will use this command when public access is enabled
  # wget https://gerrit.acumos.org/r/gitweb?p=common-dataservice.git;a=blob_plain;f=cmn-data-svc-server/db-scripts/cmn-data-svc-ddl-dml-mysql-$ACUMOS_CDS_VERSION.sql;hb=HEAD
  sed -i -- "1s/^/use $ACUMOS_CDS_DB;\n/" cmn-data-svc-ddl-dml-mysql-$ACUMOS_CDS_VERSION.sql
  mysql --user=acumos_opr --password=$MARIADB_USER_PASSWORD < cmn-data-svc-ddl-dml-mysql-$ACUMOS_CDS_VERSION.sql

  log "Setup database 'acumos_comment'"
  mysql --user=root --password=$MARIADB_PASSWORD -e "CREATE DATABASE acumos_comment; USE acumos_comment; GRANT ALL PRIVILEGES ON acumos_comment.* TO 'acumos_opr'@'%' IDENTIFIED BY \"$MARIADB_USER_PASSWORD\";"

  log "Setup database 'acumos_cms'"
  mysql --user=root --password=$MARIADB_PASSWORD -e "CREATE DATABASE acumos_cms; USE acumos_cms; GRANT ALL PRIVILEGES ON acumos_cms.* TO 'acumos_opr'@'%' IDENTIFIED BY \"$MARIADB_USER_PASSWORD\";"
}

setup_nexus_repo() {
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
  while ! curl -v -u admin:admin123 http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_API_PORT/service/rest/v1/script ; do
    log "Waiting 10 seconds for nexus server to respond"
    sleep 10
  done

  setup_nexus_repo 'acumos_model_maven' 'Maven' $ACUMOS_MAVEN_MODEL_PORT
  setup_nexus_repo 'acumos_model_docker' 'Docker' $ACUMOS_DOCKER_MODEL_PORT
  setup_nexus_repo 'acumos_platform_docker' 'Docker' $ACUMOS_DOCKER_PLATFORM_PORT

  log "Add nexus roles and users"
  cat <<EOF >nexus-script.json
{
  "name": "add-roles-users",
  "type": "groovy",
  "content": "security.addRole(\"acumos_ro\", \"acumos_ro\", \"Read Only\", [\"nx-search-read\", \"nx-repository-view-*-*-read\", \"nx-repository-view-*-*-browse\"], []); security.addRole(\"acumos_rw\", \"acumos_rw\", \"Read Write\", [\"nx-search-read\", \"nx-repository-view-*-*-read\", \"nx-repository-view-*-*-browse\", \"nx-repository-view-*-*-add\", \"nx-repository-view-*-*-edit\", \"nx-apikey-all\"], []); security.addUser(\"acumos_ro\", \"Acumos\", \"Read Only\", \"acumos@example.com\", true, \"$ACUMOS_RO_USER_PASSWORD\", [\"acumos_ro\"]); security.addUser(\"acumos_rw\", \"Acumos\", \"Read Write\", \"acumos@example.com\", true, \"$ACUMOS_RW_USER_PASSWORD\", [\"acumos_rw\"]);"
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

function setup_localindex() {
  log "Setup local python index"
  sudo apt-get install -y python-twisted-core
  nohup twistd -n web --port 8087 --path .  > /dev/null 2>&1 &
}

function setup_acumos() {
  log "Log into LF Nexus Docker repos"
  sudo docker login https://nexus3.acumos.org:10004 -u docker -p docker
  sudo docker login https://nexus3.acumos.org:10003 -u docker -p docker
  sudo docker login https://nexus3.acumos.org:10002 -u docker -p docker
  log "Deploy Acumos docker containers"
  sudo bash docker-compose.sh build
  sudo bash docker-compose.sh up -d
}

function setup_reverse_proxy() {
  log "Install keytool"
  sudo apt-get install -y openjdk-9-jre-headless

  log "Generate public private key pair using keytool"
  # TODO: use these randomly generated credentials
  keypass=$(uuidgen)
  storepass=$(uuidgen)
  mkdir certs
  keytool -genkeypair -keystore certs/acumos.jks -storepass password \
   -alias acumos -keyalg RSA -keysize 2048 -validity 5000 -keypass password \
   -dname 'CN=*.acumos, OU=Acumos, O=Acumos, L=Unspecified, ST=Unspecified, C=US' \
   -ext "SAN=DNS:$ACUMOS_PORTAL_FE_HOSTNAME,DNS:$ACUMOS_ONBOARDING_HOSTNAME,DNS:acumos"

  log "Generate PEM encoded public certificate file using keytool"
  keytool -exportcert -keystore certs/acumos.jks -alias acumos -rfc \
    -storepass password > certs/acumos.cert

  log "Convert the Java specific keystore binary '.jks' file to a widely compatible PKCS12 keystore '.p12' file"
  keytool -importkeystore -srckeystore certs/acumos.jks \
    -destkeystore certs/acumos.p12 -deststoretype PKCS12 \
    -srcstorepass password -deststorepass password \
    -srckeypass password -alias acumos -destalias acumos

  log "List new keystore file contents"
  keytool -list -keystore certs/acumos.p12 -storetype PKCS12 -storepass password

  log "Generate example.pem"
  openssl pkcs12 -nokeys -in certs/acumos.p12 -out certs/acumos.pem \
    -password pass:password

  log "Extract unencrypted private key file from '.p12' keystore file"
  openssl pkcs12 -nocerts -nodes -in certs/acumos.p12 -out certs/acumos.key \
    -password pass:password

  log "Pass cert and key to Kong admin"
  curl -i -X POST http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/certificates \
    -F "cert=@certs/acumos.pem" \
    -F "key=@certs/acumos.key" \
    -F "snis=$ACUMOS_PORTAL_FE_HOSTNAME,$ACUMOS_ONBOARDING_HOSTNAME,acumos"

  log "Add proxy entries via Kong API"
  curl -i -X POST \
    --url http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/apis/ \
    --data "https_only=true" \
    --data "name=root" \
    --data "upstream_url=http://$ACUMOS_PORTAL_FE_HOST:$ACUMOS_PORTAL_FE_PORT" \
    --data "uris=/" \
    --data "strip_uri=false"
  curl -i -X POST \
    --url http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/apis/ \
    --data "name=onboarding-app" \
    --data "upstream_url=http://$ACUMOS_HOSTNAME:$ACUMOS_ONBOARDING_PORT/onboarding-app" \
    --data "uris=/onboarding-app" \
    --data "strip_uri=false"

  log "Dump of API endpoints as created"
  curl http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/apis/

  log "Add cert as CA to docker /etc/docker/certs.d"
  # Required for docker daemon to accept the kong self-signed cert
  # Per https://docs.docker.com/registry/insecure/#use-self-signed-certificates
  sudo mkdir -p /etc/docker/certs.d/$ACUMOS_HOST
  sudo cp certs/acumos.cert /etc/docker/certs.d/$ACUMOS_HOST/ca.crt
}

function setup_dns() {
  log "Add Acumos hostnames to /etc/hosts"
  sudo sed -i -- "/$ACUMOS_HOST/d" /etc/hosts
  cat <<EOF | sudo tee -a /etc/hosts
$ACUMOS_PORTAL_FE_HOST $ACUMOS_PORTAL_FE_HOSTNAME
$ACUMOS_ONBOARDING_HOST $ACUMOS_ONBOARDING_HOSTNAME
$ACUMOS_NEXUS_HOST nexus
EOF
}

export WORK_DIR=$(pwd)
log "Reset acumos-env.sh"
sed -i -- '/MARIADB_PASSWORD/d' acumos-env.sh
sed -i -- '/MARIADB_USER_PASSWORD/d' acumos-env.sh
sed -i -- '/ACUMOS_RO_USER_PASSWORD/d' acumos-env.sh
sed -i -- '/ACUMOS_RW_USER_PASSWORD/d' acumos-env.sh
sed -i -- '/ACUMOS_HOST_DOCKER0/d' acumos-env.sh
sed -i -- '/ACUMOS_CDS_PASSWORD/d' acumos-env.sh

MARIADB_PASSWORD=$(uuidgen)
echo "MARIADB_PASSWORD=\"$MARIADB_PASSWORD\"" >>acumos-env.sh
echo "export MARIADB_PASSWORD" >>acumos-env.sh
MARIADB_USER_PASSWORD=$(uuidgen)
echo "MARIADB_USER_PASSWORD=\"$MARIADB_USER_PASSWORD\"" >>acumos-env.sh
echo "export MARIADB_USER_PASSWORD" >>acumos-env.sh
ACUMOS_RO_USER_PASSWORD=$(uuidgen)
echo "ACUMOS_RO_USER_PASSWORD=\"$ACUMOS_RO_USER_PASSWORD\"" >>acumos-env.sh
echo "export ACUMOS_RO_USER_PASSWORD" >>acumos-env.sh
ACUMOS_RW_USER_PASSWORD=$(uuidgen)
echo "ACUMOS_RW_USER_PASSWORD=\"$ACUMOS_RW_USER_PASSWORD\"" >>acumos-env.sh
echo "export ACUMOS_RW_USER_PASSWORD" >>acumos-env.sh
ACUMOS_CDS_PASSWORD=$(uuidgen)
echo "ACUMOS_CDS_PASSWORD=\"$ACUMOS_CDS_PASSWORD\"" >>acumos-env.sh
echo "export ACUMOS_CDS_PASSWORD" >>acumos-env.sh
docker_ifs=$(ifconfig | grep 172. | cut -d ':' -f 2 | cut -d ' ' -f 1)
#echo "ACUMOS_HOST_DNS=$(ifconfig | grep 172. | cut -d ':' -f 2 | cut -d ' ' -f 1)" >>acumos-env.sh
echo "ACUMOS_HOST_DNS=172.18.0.1" >>acumos-env.sh
echo "export ACUMOS_HOST_DNS" >>acumos-env.sh
source acumos-env.sh

setup_prereqs
setup_dns
setup_mariadb
setup_acumosdb
setup_localindex
setup_acumos
setup_nexus
setup_reverse_proxy

log "Deploy is complete. You can access the portal at https://$ACUMOS_DOMAIN, assuming you have added that hostname to your hosts file."
