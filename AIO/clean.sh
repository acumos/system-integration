#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2018-2019 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
# - Must be run by a user with sudo privilege
#
# Usage:
# $ bash clean.sh [prune]
#   prune: remove unused docker images
#
# If clean does not stop all docker based containers, force cleanup via:
# $ cs=$(sudo docker ps -a | awk '{print $1}'); for c in $cs; do sudo docker stop $c; sudo docker rm -v $c; done
# To periodically clean up extra docker volumes:
# $ vs=$(sudo ls -1 /var/lib/docker/volumes); for v in $vs; do sudo docker volume rm $v; done

set -x
WORK_DIR=$(pwd)
cd $(dirname "$0")
source acumos_env.sh
nss="$ACUMOS_NAMESPACE $ACUMOS_MARIADB_NAMESPACE $ACUMOS_ELK_NAMESPACE"
if [[ $(kubectl get namespaces) ]]; then
  if [[ "$(helm list -a | grep -v 'NAME' | awk '{print $1}')" != "" ]]; then
    rlss=$(helm list -a | grep -v 'NAME' | awk '{print $1}')
    for rls in $rlss; do
      helm delete --purge $rls
    done
  fi
  if [[ "$K8S_DIST" == "openshift" ]]; then
    for ns in $nss; do
      echo "Delete project $ns"
      oc delete project $ns
      while oc project $ns; do
        echo "Waiting 10 seconds for project $ns to be deleted"
        sleep 10
      done
    done
  else
    for ns in $nss; do
      echo "Delete namespace $ns"
      kubectl delete namespace $ns
      while kubectl namespace $ns; do
        echo "Waiting 10 seconds for namespace $ns to be deleted"
        sleep 10
      done
    done
  fi
fi

if [[ $(docker ps -a | grep -c 'acumos_') -gt 0 ]]; then
  if [[ "$DEPLOYED_UNDER" == "docker" || "$DEPLOYED_UNDER" == "" ]]; then
    cs=$(docker ps -a | awk "/acumos_/{print \$1}")
    for c in $cs; do
      docker stop $c
      docker rm -v $c
    done
  fi
fi

if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
  echo "Cleanup any PV folders"
  for ns in $nss; do
    ds=$(ls /mnt/$ns | grep -v docker)
    for d in $ds; do
      sudo rm -rf /mnt/$ns/$d/*
    done
  done
  echo "Cleanup any orphan docker containers"
  cs=$(docker ps --format '{{.Names}}' | grep 'acumos_')
  for c in $cs; do
    docker stop $c
    docker rm -v $c
  done
fi

if [[ "$1" == "prune" ]]; then
  echo "Cleanup unused docker images"
  docker image prune -a -f
fi

echo "You should now be able to repeat the install via oneclick_deploy.sh"
