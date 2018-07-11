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
# If clean does not stop all docker based containers, force cleanup via:
# $ cs=$(sudo docker ps -a | awk '{print $1}'); for c in $cs; do sudo docker stop $c; sudo docker rm -v $c; done
# To periodically clean up extra docker volumes:
# $ vs=$(sudo ls -1 /var/lib/docker/volumes); for v in $vs; do sudo docker volume rm $v; done

trap - ERR

set -x

source acumos-env.sh

if [[ "$DEPLOYED_UNDER" == "docker" || "$DEPLOYED_UNDER" == "" ]]; then
  echo "Stop Acumos docker-based components"
  sudo bash docker-compose.sh down
  sudo docker volume rm kong-db
  sudo docker volume rm acumos-logs
  sudo docker volume rm acumos-output
  sudo docker volume rm acumosWebOnboarding
fi

if [[ "$DEPLOYED_UNDER" == "k8s" || "$DEPLOYED_UNDER" == "" ]]; then
  echo "Stop the running Acumos component services under kubernetes"
  kubectl delete service -n acumos azure-client-service cds-service cms-service\
    filebeat-service onboarding-service portal-be-service portal-fe-service \
    dsce-service federation-service kong-service nexus-service

  echo "Stop the running Acumos component deployments under kubernetes"
  kubectl delete deployment -n acumos azure-client cds cms filebeat onboarding\
    portal-be portal-fe dsce federation kong nexus

  echo "Delete image pull secrets from kubernetes"
  kubectl delete secret acumos-registry

  echo "Delete namespace acumos"
  kubectl delete namespace acumos
  while kubectl get namespace acumos; do
    echo "Waiting 10 seconds for namespace acumos to be deleted"
    sleep 10
  done
fi

echo "Cleanup acumos data"
rm -rf /var/acumos

echo "Reset /etc/hosts customizations"
sudo sed -i -- '/nexus-service/d' /etc/hosts

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
rm /var/acumos/certs/*
rm nexus-script.json

echo "You should now be able to repeat the install via oneclick_deploy.sh"
