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
# - Ubuntu Xenial or Centos 7 server
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
  if [[ "$dist" == "ubuntu" ]]; then
    echo; echo "prereqs.sh: ($(date)) Basic prerequisites"

    wait_dpkg; sudo apt-get update
    wait_dpkg; sudo apt-get upgrade -y
    wait_dpkg; sudo apt-get install -y wget git jq apg

    echo; echo "prereqs.sh: ($(date)) Install latest docker"
    wait_dpkg; sudo apt-get install -y docker.io docker-compose
    # Alternate for 1.12.6
    #sudo apt-get install -y libltdl7
    #wget https://packages.docker.com/1.12/apt/repo/pool/main/d/docker-engine/docker-engine_1.12.6~cs8-0~ubuntu-xenial_amd64.deb
    #sudo dpkg -i docker-engine_1.12.6~cs8-0~ubuntu-xenial_amd64.deb
    sudo service docker restart
  else
    echo; echo "prereqs.sh: ($(date)) Basic prerequisites"
    sudo yum install -y epel-release
    sudo yum update -y
    sudo yum install -y wget git jq apg
    echo; echo "prereqs.sh: ($(date)) Install latest docker"
    # per https://docs.docker.com/engine/installation/linux/docker-ce/centos/#install-from-a-package
    sudo yum install -y docker docker-compose
    sudo systemctl enable docker
    sudo systemctl start docker
  #  wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-17.09.0.ce-1.el7.centos.x86_64.rpm
  #  sudo yum install -y docker-ce-17.09.0.ce-1.el7.centos.x86_64.rpm
  #  sudo systemctl start docker
  fi
  log "Create Volumes for Acumos application"
  sudo docker volume create acumos-logs
  sudo docker volume create acumos-output
  sudo docker volume create acumosWebOnboarding
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
  MARIADB_PASSWORD=$(/usr/bin/apg -n 1 -m 16 -c cl_seed)
  echo "MARIADB_PASSWORD=\"$MARIADB_PASSWORD\"" >>acumos-env.sh
  echo "export MARIADB_PASSWORD" >>acumos-env.sh
  export MARIADB_PASSWORD
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
  MARIADB_USER_PASSWORD=$(/usr/bin/apg -n 1 -m 16 -c cl_seed)
  echo "MARIADB_USER_PASSWORD=\"$MARIADB_USER_PASSWORD\"" >>acumos-env.sh
  echo "export MARIADB_USER_PASSWORD" >>acumos-env.sh
  export MARIADB_USER_PASSWORD
  source acumos-env.sh

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

function setup_nexus() {
  sudo docker run -d -p $ACUMOS_NEXUS_PORT:8081 --name nexus sonatype/nexus3
  while ! curl -v -u admin:admin123 http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_PORT/service/rest/v1/script ; do
    log "Waiting 10 seconds for nexus server to respond"
    sleep 10
  done
  log "Create Nexus repo acumos_model_maven"
  # For into on Nexus script API and groovy scripts, see
  # https://github.com/sonatype/nexus-book-examples/tree/nexus-3.x/scripting
  # https://help.sonatype.com/display/NXRM3/Examples
  cat <<EOF >nexus-script.json
{
  "name": "acumos_model_maven",
  "type": "groovy",
  "content": "repository.createMavenHosted('acumos_model_maven')"
}
EOF
  curl -v -u admin:admin123 -H "Content-Type: application/json" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_PORT/service/rest/v1/script/ -d @nexus-script.json
  # TODO: verify script creation via jq parse of
  # curl -v -u admin:admin123 'http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_PORT/service/rest/v1/script'
  curl -v -X POST -u admin:admin123 -H "Content-Type: text/plain" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_PORT/service/rest/v1/script/acumos_model_maven/run

  repos="acumos_model_docker acumos_platform_docker"
  for repo in $repos ; do
    log "Create Nexus repo $repo"
  # Parameters per javadoc
  # org.sonatype.nexus.repository.Repository createDockerHosted(String name,
  #   Integer httpPort,
  #   Integer httpsPort,
  #   String blobStoreName,
  #   boolean v1Enabled,
  #   boolean strictContentTypeValidation,
  #   org.sonatype.nexus.repository.storage.WritePolicy writePolicy)
  # Only first three parameters used due to unclear how to script blobstore
  # creation and how to specify writePolicy ('ALLOW' was not recognized)
    cat <<EOF >nexus-script.json
{
  "name": "$repo",
  "type": "groovy",
  "content": "repository.createDockerHosted(\"$repo\", null, null)"
}
EOF
    curl -v -u admin:admin123 -H "Content-Type: application/json" \
      http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_PORT/service/rest/v1/script/ -d @nexus-script.json
    # TODO: verify script creation
    curl -v -X POST -u admin:admin123 -H "Content-Type: text/plain" \
      http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_PORT/service/rest/v1/script/$repo/run
  done

  ACUMOS_RO_USER_PASSWORD=$(/usr/bin/apg -n 1 -m 16 -c cl_seed)
  echo "ACUMOS_RO_USER_PASSWORD=\"$ACUMOS_RO_USER_PASSWORD\"" >>acumos-env.sh
  echo "export ACUMOS_RO_USER_PASSWORD" >>acumos-env.sh
  export ACUMOS_RO_USER_PASSWORD

  ACUMOS_RW_USER_PASSWORD=$(/usr/bin/apg -n 1 -m 16 -c cl_seed)
  echo "ACUMOS_RW_USER_PASSWORD=\"$ACUMOS_RW_USER_PASSWORD\"" >>acumos-env.sh
  echo "export ACUMOS_RW_USER_PASSWORD" >>acumos-env.sh
  export ACUMOS_RW_USER_PASSWORD

  log "Add nexus roles and users"
  cat <<EOF >nexus-script.json
{
  "name": "add-roles-users",
  "type": "groovy",
  "content": "security.addRole(\"acumos_ro\", \"acumos_ro\", \"Read Only\", [\"nx-search-read\", \"nx-repository-view-*-*-read\", \"nx-repository-view-*-*-browse\"], []); security.addRole(\"acumos_rw\", \"acumos_rw\", \"Read Write\", [\"nx-search-read\", \"nx-repository-view-*-*-read\", \"nx-repository-view-*-*-browse\", \"nx-repository-view-*-*-add\", \"nx-repository-view-*-*-edit\", \"nx-apikey-all\"], []); security.addUser(\"acumos_ro\", \"Acumos\", \"Read Only\", \"acumos@example.com\", true, \"$ACUMOS_RO_USER_PASSWORD\", [\"acumos_ro\"]); security.addUser(\"acumos_rw\", \"Acumos\", \"Read Write\", \"acumos@example.com\", true, \"$ACUMOS_RW_USER_PASSWORD\", [\"acumos_rw\"]);"
}
EOF
  curl -v -u admin:admin123 -H "Content-Type: application/json" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_PORT/service/rest/v1/script/ -d @nexus-script.json
  # TODO: verify script creation
  curl -v -X POST -u admin:admin123 -H "Content-Type: text/plain" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_PORT/service/rest/v1/script/add-roles-users/run

  log "Show nexus users"
  cat <<EOF >nexus-script.json
{
  "name": "list-users",
  "type": "groovy",
  "content": "import groovy.json.JsonOutput; import org.sonatype.nexus.security.user.User; users = security.getSecuritySystem().listUsers(); size = users.size(); log.info(\"User count: $size\"); return JsonOutput.toJson(users)"
}
EOF
  curl -v -u admin:admin123 -H "Content-Type: application/json" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_PORT/service/rest/v1/script/ -d @nexus-script.json
  curl -v -X POST -u admin:admin123 -H "Content-Type: text/plain" \
    http://$ACUMOS_NEXUS_HOST:$ACUMOS_NEXUS_PORT/service/rest/v1/script/list-users/run
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

export WORK_DIR=$(pwd)
log "Reset acumos-env.sh"
sed -i -- '/MARIADB_PASSWORD/d' acumos-env.sh
sed -i -- '/MARIADB_USER_PASSWORD/d' acumos-env.sh
sed -i -- '/ACUMOS_RO_USER_PASSWORD/d' acumos-env.sh
sed -i -- '/ACUMOS_RW_USER_PASSWORD/d' acumos-env.sh
source acumos-env.sh

setup_prereqs
setup_mariadb
setup_acumosdb
setup_nexus
setup_acumos
