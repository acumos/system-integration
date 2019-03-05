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
# $ bash clean.sh [namespace]
#   namespace: value to assign to ACUMOS_NAMESPACE (default: acumos)
#
# If clean does not stop all docker based containers, force cleanup via:
# $ cs=$(sudo docker ps -a | awk '{print $1}'); for c in $cs; do sudo docker stop $c; sudo docker rm -v $c; done
# To periodically clean up extra docker volumes:
# $ vs=$(sudo ls -1 /var/lib/docker/volumes); for v in $vs; do sudo docker volume rm $v; done

set -x
trap 'exit 1' ERR
trap '' ERR

if [[ "$1" == "" ]]; then ACUMOS_NAMESPACE=acumos
else ACUMOS_NAMESPACE=$1
fi

if [[ $(which kubectl) ]]; then
  if [[ $(kubectl get namespaces $ACUMOS_NAMESPACE) ]]; then
    if [[ $(which oc) ]]; then
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
  pvs=$(kubectl get pv | awk "/$ACUMOS_NAMESPACE/{print \$1}")
  for pv in $pvs; do
    kubectl delete pv $pv
  done
else
  if [[ $(sudo docker ps -a | grep -c ' acumos_') -gt 0 ]]; then
    cs=$(sudo docker ps --format '{{.Names}}' | grep ' acumos_')
    for c in $cs; do
      sudo docker stop $c
      sudo docker rm -v $c
    done
  fi

  echo "Cleanup unused docker images"
  sudo docker image prune -a -f
fi

echo "Delete persistent volume host folder"
sudo rm -rf /var/$ACUMOS_NAMESPACE/logs
sudo rm -rf /var/$ACUMOS_NAMESPACE/kong-db
sudo rm -rf /var/$ACUMOS_NAMESPACE/docker-volume
sudo rm -rf /var/$ACUMOS_NAMESPACE/nexus-data
sudo rm -rf /var/$ACUMOS_NAMESPACE/mariadb-data
sudo rm -rf /var/$ACUMOS_NAMESPACE/elasticsearch-data

echo "Clean up logs etc"
sudo rm -rf /tmp/acumos

echo "You should now be able to repeat the install via oneclick_deploy.sh"
