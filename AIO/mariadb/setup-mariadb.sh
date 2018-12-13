#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2018 AT&T Intellectual Property. All rights reserved.
# ===================================================================================
# This Acumos software file is distributed by AT&T
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
#. What this is: script to setup the mariadb for Acumos, under docker or k8s
#.
#. Prerequisites:
#. - Acumos core components through oneclick_deploy.sh
#.
#. Usage: intended to be called directly from oneclick_deploy.sh
#. NOTE: Redeploying MariaDB with an existing DB is not yet supported
#.

function set_repo() {
  sudo apt-get install software-properties-common -y
  case "$ACUMOS_HOST_OS_VER" in
    "16.04")
      log "Installing MariaDB 10.2"
      # default version
      MARIADB_VERSION='10.2'
      # May need to update to another mirror if you encounter issues
      # See https://downloads.mariadb.org/mariadb/repositories/#mirror=accretive&distro=Ubuntu
      MARIADB_REPO='deb [arch=amd64,i386,ppc64el] http://sfo1.mirrors.digitalocean.com/mariadb/repo/10.2/ubuntu xenial main'
      ;;
    "18.04")
      log "Workaround DNS issue in 18.04 affecting ability to retrieve Ubuntu key"
      sudo sed -i -- 's/nameserver 127.0.0.53/nameserver 8.8.8.8/' /etc/resolv.conf
      MARIADB_REPO='deb [arch=amd64,arm64,ppc64el] http://mirror.rackspace.com/mariadb/repo/10.2/ubuntu bionic main'
      ;;
    *)
      fail "Unsupported Ubuntu version ($ACUMOS_HOST_OS_VER)"
  esac

  log "Import mariadb repo key"
  sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
  sudo add-apt-repository "$MARIADB_REPO"
  sudo apt-get update -y
}

function setup_on_host() {
  trap 'fail' ERR
  if [[ "$ACUMOS_HOST_OS" == "ubuntu" ]]; then
    set_repo
    log "Install MariaDB without password prompt"
    sudo debconf-set-selections <<< "mariadb-server-$MARIADB_VERSION mysql-server/root_password password $ACUMOS_MARIADB_PASSWORD"
    sudo debconf-set-selections <<< "mariadb-server-$MARIADB_VERSION mysql-server/root_password_again password $ACUMOS_MARIADB_PASSWORD"

    log "Install MariaDB"
    sudo apt-get install -y -q mariadb-server-$MARIADB_VERSION

    sudo sed -i 's/^\!includedir.*//' /etc/mysql/my.cnf
    cat << EOF | sudo tee -a /etc/mysql/my.cnf
# Added to use lower case for all tablenames.
[mariadb-10.2]
lower_case_table_names=1
!includedir /etc/mysql/mariadb.conf.d/
EOF

    log "Make MariaDB connectable from outside"
    sudo sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/my.cnf
  else
  # Add MariaDB 10 external yum repo
    cat << EOF | sudo tee -a /etc/yum.repos.d/MariaDB.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.2/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
    sudo yum install -y MariaDB-server MariaDB-client

    log "Configure MariaDB"
    FILE=/etc/my.cnf.d/server.cnf
    LINE='bind-address = 0.0.0.0'
    sudo sed -i -e "\|$LINE|h; \${x;s|$LINE||;{g;t};a\\" -e "$LINE" -e "}" $FILE
    LINE='lower_case_table_names=1'
    sudo sed -i -e "\|$LINE|h; \${x;s|$LINE||;{g;t};a\\" -e "$LINE" -e "}" $FILE
    LINE='skip-grant-tables'
    sudo sed -i -e "\|$LINE|h; \${x;s|$LINE||;{g;t};a\\" -e "$LINE" -e "}" $FILE
  fi

  sudo systemctl daemon-reload
  sudo service mysql restart

  log "Secure mysql installation"
  if [[ "$ACUMOS_HOST_OS" == "ubuntu" ]]; then
    mysql --user=root --password=$ACUMOS_MARIADB_PASSWORD -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1','::1'); DELETE FROM mysql.user WHERE User=''; DELETE FROM mysql.db WHERE Db='test' OR Db='test_%'; FLUSH PRIVILEGES;"
  else
    mysql --user=root -e "UPDATE mysql.user SET Password=PASSWORD('$ACUMOS_MARIADB_PASSWORD') WHERE User='root'; DELETE FROM mysql.user WHERE User=''; DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1'); DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'; FLUSH PRIVILEGES;"
    sudo systemctl stop mysql
    sudo sed -i "/skip-grant-tables/d" /etc/my.cnf.d/server.cnf
    sudo systemctl daemon-reload
    sudo service mysql restart
  fi
}

function setup_in_docker() {
  trap 'fail' ERR

  if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
    log "Install mariadb client for database setup"
    if [[ "$ACUMOS_HOST_OS" == "ubuntu" ]]; then
      set_repo
      sudo apt-get install -y mariadb-client
    else
    # Add MariaDB 10 external yum repo
      cat << EOF | sudo tee -a /etc/yum.repos.d/MariaDB.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.2/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
      sudo yum install -y MariaDB-client
    fi
  fi

# Redeploying MariaDB with an existing DB is not yet supported
#  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
#    sudo bash docker-compose.sh $AIO_ROOT down
#  else
#    stop_service deploy/mariadb-service.yaml
#    stop_deployment deploy/mariadb-deployment.yaml
#    log "Delete the mariadb-data PVC"
#    bash $AIO_ROOT/setup-pv.sh clean pvc mariadb-data
#  fi

  log "Setup the mariadb-data PV"
  bash $AIO_ROOT/setup-pv.sh setup pv mariadb-data \
    $PV_SIZE_MARIADB_DATA "$USER:$USER"

  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    sudo bash docker-compose.sh $AIO_ROOT up -d --build --force-recreate
  else
    log "Setup the mariadb-data PVC"
    bash $AIO_ROOT/setup-pv.sh setup pvc mariadb-data \
      $PV_SIZE_MARIADB_DATA

    if [[ "$K8S_DIST" == "openshift" ]]; then
      log "Workaround variation in OpenShift for external access to mariadb"
      sed -i -- 's/<ACUMOS_HOST>/172.17.0.1/' kubernetes/mariadb-deployment.yaml
    fi

    mkdir -p deploy
    cp -r kubernetes/* deploy/.
    replace_env deploy "ACUMOS_NAMESPACE ACUMOS_HOST ACUMOS_DOMAIN \
      ACUMOS_MARIADB_ADMINER_NODEPORT ACUMOS_MARIADB_NODEPORT \
      ACUMOS_MARIADB_PASSWORD ACUMOS_MARIADB_USER_PASSWORD ACUMOS_CDS_DB"

    start_service deploy/mariadb-service.yaml
    start_deployment deploy/mariadb-deployment.yaml
  fi

  wait_running mariadb-service

  log "Wait for mariadb server to accept connections"
  if [[ "$ACUMOS_MARIADB" == "in-docker" ]]; then
    server="-h $ACUMOS_HOST -P $ACUMOS_MARIADB_NODEPORT"
  fi
  while ! mysql $server --user=root --password=$ACUMOS_MARIADB_PASSWORD \
    -e "SHOW DATABASES;" ; do
    log "Mariadb server is not yet accepting connections from $ACUMOS_HOST"
    sleep 10
  done
}

source $AIO_ROOT/acumos-env.sh
source $AIO_ROOT/utils.sh
# Create the following only if deploying with a new DB
if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
  sed -i -- '/ACUMOS_MARIADB_PASSWORD/d' $AIO_ROOT/acumos-env.sh
  sed -i -- '/ACUMOS_MARIADB_USER_PASSWORD/d' $AIO_ROOT/acumos-env.sh
  ACUMOS_MARIADB_PASSWORD=$(uuidgen)
  echo "ACUMOS_MARIADB_PASSWORD=\"$ACUMOS_MARIADB_PASSWORD\"" >>$AIO_ROOT/acumos-env.sh
  echo "export ACUMOS_MARIADB_PASSWORD" >>$AIO_ROOT/acumos-env.sh
  ACUMOS_MARIADB_USER_PASSWORD=$(uuidgen)
  echo "ACUMOS_MARIADB_USER_PASSWORD=\"$ACUMOS_MARIADB_USER_PASSWORD\"" >>$AIO_ROOT/acumos-env.sh
  echo "export ACUMOS_MARIADB_USER_PASSWORD" >>$AIO_ROOT/acumos-env.sh
  source $AIO_ROOT/acumos-env.sh
fi

if [[ "$ACUMOS_MARIADB" == "in-docker" ]]; then
  setup_in_docker
else
  setup_on_host
fi
