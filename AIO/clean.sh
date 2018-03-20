#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
# What this is: cleanup script for an All-in-One deployment of the Acumos platform.
# Prerequisites:
# - Acumos AIO installed per oneclick_deploy.sh
# - If the docker-compose console is still running, showing the logs of the
#   containers, ctrl-c to stop it and wait will all services are stopped.
# Usage:
# $ bash clean.sh
#

trap - ERR

source acumos-env.sh

echo "Stop the running Acumos component containers"
sudo bash docker-compose.sh down
sudo bash docker-compose.sh rm -v

echo "Remove Acumos databases and users"
mysql --user=root --password=$MARIADB_PASSWORD -e "DROP DATABASE $ACUMOS_CDS_DB; DROP DATABASE acumos_comment;  DROP DATABASE acumos_cms; DROP USER 'acumos_opr'@'%';"
 if [[ $? -eq 1 ]]; then
  echo "Remove all mysql data"
  sudo rm -rf /var/lib/mysql
fi

echo "Remove mariadb-server"
sudo apt-get remove mariadb-server-10.2 -y
# To prevent issues later with apt-get update
sudo rm /etc/apt/sources.list.d/mariadb.list
sudo apt-get clean

echo "Remove Kong certs etc"
rm -rf certs
rm nexus-script.json

echo "You should now be able to repeat the install via oneclick_deploy.sh"
