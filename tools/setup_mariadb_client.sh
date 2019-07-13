#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2019 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
# What this is: Prerequisite MariaDB client setup script for All-in-One (AIO)
# deployment of the Acumos platform under kubernetes. This is a dependency of
# configuring the Acumos database in MariaDB, for users that install the
# Acumos platform via oneclick_deploy.sh from their workstation.
# FOR TEST PURPOSE ONLY.
#
# Prerequisites:
# - Ubuntu Xenial (16.04), Bionic (18.04), or Centos 7 hosts
# - acumos_env.sh and mariadb_env.sh created and saved in the AIO_ROOT folder
#
# Usage:
# $ bash setup_mariadb_client.sh
#

function wait_dpkg() {
  trap 'fail' ERR
  # TODO: workaround for "E: Could not get lock /var/lib/dpkg/lock - open (11: Resource temporarily unavailable)"
  log "waiting for dpkg to be unlocked"
  while $sudo_cmd fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
    sleep 1
  done
}

setup_mariadb_client() {
  trap 'fail' ERR
  get_host_info

  log "Installing MariaDB client $ACUMOS_MARIADB_VERSION"
  if [[ "$HOST_OS" == "ubuntu" ]]; then
    # This us needed to avoid random errors ala "no release file" when trying to
    # update apt, after prior mariadb install using one of the mariadb mirrors.
    # The mirrors may become unreliable, thus the MARIADB_MIRROR env param
    log "Remove any prior reference to mariadb in /etc/apt/sources.list"
    $sudo_cmd sed -i -- '/mariadb/d' /etc/apt/sources.list

    $sudo_cmd apt-get install software-properties-common -y
    case "$HOST_OS_VER" in
      "16.04")
        MARIADB_REPO="deb [arch=amd64,i386,ppc64el] http://$MARIADB_MIRROR/mariadb/repo/$ACUMOS_MARIADB_VERSION/ubuntu xenial main"
        ;;
      "18.04")
        MARIADB_REPO="deb [arch=amd64,arm64,ppc64el] http://$MARIADB_MIRROR/mariadb/repo/$ACUMOS_MARIADB_VERSION/ubuntu bionic main"
        ;;
      *)
        fail "Unsupported Ubuntu version ($HOST_OS_VER)"
    esac

    log "Import mariadb repo key"
    $sudo_cmd apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
    $sudo_cmd add-apt-repository "$MARIADB_REPO"
    $sudo_cmd apt-get update -y
    $sudo_cmd apt-get install -y mariadb-client
  else
  # Add MariaDB 10 external yum repo
    cat << EOF | $sudo_cmd tee -a /etc/yum.repos.d/MariaDB.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.2/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
    $sudo_cmd yum install -y MariaDB-client
  fi
}

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
export AIO_ROOT="$(cd ../AIO; pwd -P)"
source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh
if [[ "$(which sudo)" != "" ]]; then
  sudo_cmd=$(which sudo)
fi
if [[ $(mysql --version | grep -c "$ACUMOS_MARIADB_VERSION.*-MariaDB" ) -eq 0 ]]; then
  setup_mariadb_client
else
  log "MariaDB client is already the required version"
  mysql --version
fi
