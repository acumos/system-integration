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
# - All hostnames specified in acumos-env.sh must be DNS-resolvable on all hosts
#   (entries in /etc/hosts or in an actual DNS server)
# Usage:
# $ bash oneclick_deploy.sh
#

set -x

trap 'fail' ERR

function fail() {
  log "$1"
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
  trap 'fail' ERR

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
  trap 'fail' ERR
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
  # TODO: change default nexus admin password
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

  if [[ $(grep -c nexus /etc/hosts) -eq 0 ]]; then
    log "Add nexus to /etc/hosts"
    # have to add "/sbin" to path of IP command for centos
    echo "$ACUMOS_NEXUS_HOST nexus" | sudo tee -a /etc/hosts
  fi
}

function setup_localindex() {
  # TODO: switch to public pypi index when compatible with models (currently
  # failing when building models)
  trap 'fail' ERR
  log "Setup local python index"
  sudo apt-get install -y python-twisted-core
  nohup twistd -n web --port 8087 --path .  > /dev/null 2>&1 &
}

function docker_login() {
  while ! sudo docker login $1 -u docker -p docker ; do
    log "Docker login failed at $1, trying again"
  done
}

function setup_acumos() {
  trap 'fail' ERR
  log "Log into LF Nexus Docker repos"
  docker_login https://nexus3.acumos.org:10004
  docker_login https://nexus3.acumos.org:10003
  docker_login https://nexus3.acumos.org:10002
  log "Deploy Acumos docker containers"
  sudo bash docker-compose.sh build
  sudo bash docker-compose.sh up -d
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

  mkdir certs
  log "Create self-signing CA"
  # Customize openssl.cnf as this is needed to set CN (vs command options below)
  sed -i -- "s/<acumos-domain>/$ACUMOS_DOMAIN/" openssl.cnf
  sed -i -- "s/<acumos-host>/$ACUMOS_HOST/" openssl.cnf

  openssl genrsa -des3 -out certs/acumosCA.key -passout pass:$ACUMOS_KEYPASS 4096

  openssl req -x509 -new -nodes -key certs/acumosCA.key -sha256 -days 1024 \
   -config openssl.cnf -out certs/acumosCA.crt -passin pass:$ACUMOS_KEYPASS \
   -subj "/C=US/ST=Unspecified/L=Unspecified/O=Acumos/OU=Acumos/CN=$ACUMOS_DOMAIN"

  log "Create server certificate key"
  openssl genrsa -out certs/acumos.key -passout pass:$ACUMOS_KEYPASS 4096

  log "Create a certificate signing request for the server cert"
  # ACUMOS_HOST is used as CN since it's assumed that the client's hostname
  # is not resolvable via DNS for this AIO deploy
  openssl req -new -key certs/acumos.key -passin pass:$ACUMOS_KEYPASS \
    -out certs/acumos.csr \
    -subj "/C=US/ST=Unspecified/L=Unspecified/O=Acumos/OU=Acumos/CN=$ACUMOS_DOMAIN"

  log "Sign the CSR with the acumos CA"
  openssl x509 -req -in certs/acumos.csr -CA certs/acumosCA.crt \
    -CAkey certs/acumosCA.key -CAcreateserial -passin pass:$ACUMOS_KEYPASS \
    -extfile openssl.cnf -out certs/acumos.crt -days 500 -sha256

  log "Create PKCS12 format keystore with acumos server cert"
  openssl pkcs12 -export -in certs/acumos.crt -passin pass:$ACUMOS_KEYPASS \
    -inkey certs/acumos.key -certfile certs/acumos.crt \
    -out certs/acumos_aio.p12 -passout pass:$ACUMOS_KEYPASS

  log "Create JKS format truststore with acumos CA cert"
  keytool -import -file certs/acumosCA.crt -alias acumosCA -keypass $ACUMOS_KEYPASS \
    -keystore certs/acumosTrustStore.jks -storepass $ACUMOS_KEYPASS -noprompt
}

function setup_reverse_proxy() {
  trap 'fail' ERR
  log "Pass cert and key to Kong admin"
  curl -i -X POST http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/certificates \
    -F "cert=@certs/acumos.crt" \
    -F "key=@certs/acumos.key" \
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
    --data "upstream_url=http://$ACUMOS_PORTAL_FE_HOST:$ACUMOS_PORTAL_FE_PORT" \
    --data "uris=/" \
    --data "strip_uri=false"
  curl -i -X POST \
    --url http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/apis/ \
    --data "name=onboarding-app" \
    --data "upstream_url=http://$ACUMOS_ONBOARDING_HOST:$ACUMOS_ONBOARDING_PORT" \
    --data "uris=/onboarding-app" \
    --data "strip_uri=false"

  log "Dump of API endpoints as created"
  curl http://$ACUMOS_KONG_ADMIN_HOST:$ACUMOS_KONG_ADMIN_PORT/apis/

  log "Add cert as CA to docker /etc/docker/certs.d"
  # Required for docker daemon to accept the kong self-signed cert
  # Per https://docs.docker.com/registry/insecure/#use-self-signed-certificates
  sudo mkdir -p /etc/docker/certs.d/$ACUMOS_HOST
  sudo cp certs/acumosCA.crt /etc/docker/certs.d/$ACUMOS_HOST/ca.crt
}

function setup_federation() {
  trap 'fail' ERR
  log "Create 'self' peer entry (required) via CDS API"
  while ! curl -s -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/peer ; do
    log "CDS API is not yet responding... waiting 10 seconds"
    sleep 10
  done
  curl -s -o /tmp/json -u $ACUMOS_CDS_USER:$ACUMOS_CDS_PASSWORD -X POST http://$ACUMOS_CDS_HOST:$ACUMOS_CDS_PORT/ccds/peer -H "accept: */*" -H "Content-Type: application/json" -d "{ \"name\":\"$ACUMOS_DOMAIN\", \"self\": true, \"local\": false, \"contact1\": \"admin@example.com\", \"subjectName\": \"$ACUMOS_DOMAIN\", \"apiUrl\": \"https://$ACUMOS_DOMAIN:$ACUMOS_FEDERATION_PORT\",  \"statusCode\": \"AC\", \"validationStatusCode\": \"PS\" }"
  created=$(jq -r '.created' /tmp/json)
  if [[ "$created" == "null" ]]; then
    cat /tmp/json
    fail "Peer entry creation failed"
  fi
}

export WORK_DIR=$(pwd)
log "Reset acumos-env.sh"
sed -i -- '/MARIADB_PASSWORD/d' acumos-env.sh
sed -i -- '/MARIADB_USER_PASSWORD/d' acumos-env.sh
sed -i -- '/ACUMOS_RO_USER_PASSWORD/d' acumos-env.sh
sed -i -- '/ACUMOS_RW_USER_PASSWORD/d' acumos-env.sh
sed -i -- '/ACUMOS_CDS_PASSWORD/d' acumos-env.sh
sed -i -- '/ACUMOS_KEYPASS/d' acumos-env.sh

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
# TODO: Various components hardcode password ccds_client
echo "ACUMOS_CDS_PASSWORD=$ACUMOS_CDS_PASSWORD" >>acumos-env.sh
echo "export ACUMOS_CDS_PASSWORD" >>acumos-env.sh
docker_ifs=$(ifconfig | grep 172. | cut -d ':' -f 2 | cut -d ' ' -f 1)
#echo "ACUMOS_HOST_DNS=$(ifconfig | grep 172. | cut -d ':' -f 2 | cut -d ' ' -f 1)" >>acumos-env.sh
echo "ACUMOS_HOST_DNS=172.18.0.1" >>acumos-env.sh
echo "export ACUMOS_HOST_DNS" >>acumos-env.sh
ACUMOS_KEYPASS=$(uuidgen)
echo "ACUMOS_KEYPASS=$ACUMOS_KEYPASS" >>acumos-env.sh
echo "export ACUMOS_KEYPASS" >>acumos-env.sh

source acumos-env.sh

setup_prereqs
setup_mariadb
setup_keystore
setup_acumosdb
setup_localindex
setup_acumos
setup_nexus
setup_reverse_proxy
setup_federation

log "Deploy is complete. You can access the portal at https://$ACUMOS_DOMAIN (assuming you have added that hostname to your hosts file)"
