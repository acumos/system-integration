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
# $ bash clean.sh [prune]
#   prune: remove unused docker images
#
# If clean does not stop all docker based containers, force cleanup via:
# $ cs=$(sudo docker ps -a | awk '{print $1}'); for c in $cs; do sudo docker stop $c; sudo docker rm -v $c; done
# To periodically clean up extra docker volumes:
# $ vs=$(sudo ls -1 /var/lib/docker/volumes); for v in $vs; do sudo docker volume rm $v; done

set -x
trap 'exit 1' ERR
source acumos-env.sh
source utils.sh
trap '' ERR

AIO_ROOT=$(pwd)

if [[ $(which kubectl) ]]; then
  if [[ $(kubectl get namespaces) ]]; then
    if [[ "$K8S_DIST" == "openshift" ]]; then
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
      svcs=$(kubectl get svc -n $ACUMOS_NAMESPACE | awk '/-/{print $1}')
      for svc in $svcs; do
        log "Deleting service $svc"
        stop_service $svc
        while kubectl get svc -n $ACUMOS_NAMESPACE $svc ; do
          log "Waiting 10 seconds..."
          sleep 10
        done
      done
      deps=$(kubectl get deployments -n $ACUMOS_NAMESPACE -o json >/tmp/json)
      nd=$(jq -r '.content | length' /tmp/json)
      i=0;
      while [[ $i -lt $nd ]] ; do
        dep=$(jq -r ".items[$i].metadata.name" /tmp/json)
        log "Deleting deployment $dep"
        kubectl delete deployment -n $ACUMOS_NAMESPACE $dep
        while kubectl get pod -n $ACUMOS_NAMESPACE $dep ; do
          log "Waiting 10 seconds..."
          sleep 10
        done
      done
    fi
    echo "Delete persistent volumes"
    # k8s PVCs are deleted by namespace deletion above
    pvs="nexus-data kong-db logs output webonboarding certs docker-volume \
      elasticsearch-data mariadb-data"
    for pv in $pvs; do
      kubectl delete pv pv-$ACUMOS_NAMESPACE-$pv
    done
  fi
fi

if [[ $(sudo docker ps -a | grep $ACUMOS_NAMESPACE) ]]; then
  if [[ "$DEPLOYED_UNDER" == "docker" || "$DEPLOYED_UNDER" == "" ]]; then
    cs=$(sudo docker ps -a | awk "/$ACUMOS_NAMESPACE/{print \$1}")
    for c in $cs; do
      sudo docker stop $c
      sudo docker rm -v $c
    done
  fi
fi

echo "Cleanup any orphan docker containers"
cs=$(sudo docker ps --format '{{.Names}}' | grep acumos)
for c in $cs; do
  sudo docker stop $c
  sudo docker rm -v $c
done

if [[ "$1" == "prune" ]]; then
  echo "Cleanup unused docker images"
  sudo docker image prune -a -f
fi

echo "Delete persistent volume host folder"
sudo rm -rf /var/$ACUMOS_NAMESPACE

echo "You should now be able to repeat the install via oneclick_deploy.sh"
