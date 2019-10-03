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
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
source utils.sh
source acumos_env.sh
source mlwb/mlwb_env.sh
if [[ $(kubectl get namespaces) ]]; then
  releases="mariadb elk couchdb jenkins jupyterhub nginx-ingress zeppelin"
  for release in $releases; do
    rlss=$(helm list | grep $release | awk '{print $1}')
    for rls in $rlss; do
      if [[ $(helm delete --purge $rls) ]]; then
        log "Helm release $rls deleted"
      fi
    done
  done
  nss=$(kubectl get namespace | grep acumos | awk '{print $1}')
  for ns in $nss; do
    ks="deployment replicaset daemonset pod pvc service"
    for k in $ks; do
      rs=$(kubectl get $k -n $ns | grep -v NAME | awk '{print $1}')
      for r in $rs ; do
        echo; echo $r
        if [[ $(kubectl delete $k -n $ns $r) ]]; then
          log "$k $r deleted in namespace $ns"
        fi
      done
    done
    log "Cleanup any evicted pods in namespace $ns"
    es=$(kubectl get pods -n $ns | awk '/Evicted/{print $1}')
    for e in $es; do
      kubectl delete pod -n $ns $e
    done
    log "Attempting to cleanup all remaining resources in namespace $ns"
    log "Please be patient, this may take some minutes"
    if [[ $(kubectl delete namespace $ns) ]]; then
      log "Namespace $ns deleted"
    fi
  done
#  pvs=$(kubectl get pv | grep -v NAME | awk '{print $1}')
#  for pv in $pvs ; do
#    kubectl delete pv $pv
#  done
#  cleanup_stuck_pvs
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

log "Cleanup any stuck PVs"
pvs=$(kubectl get pv | awk '/Failed/{print $1}'); for pv in $pvs ; do kubectl patch pv $pv --type json -p '[{ "op": "remove", "path": "/spec/claimRef" }]'; done

log "Cleanup any PV folders"
for ns in $nss; do
  if [[ -e /mnt/$ns ]]; then
    sudo rm -rf /mnt/$ns
  fi
done

if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
  log "Cleanup any orphan docker containers"
  if [[ "$(docker ps --format '{{.Names}}' | grep 'acumos_')" != "" ]]; then
    cs=$(docker ps --format '{{.Names}}' | grep 'acumos_')
    for c in $cs; do
      docker stop $c
      docker rm -v $c
    done
  fi
fi

if [[ "$1" == "prune" ]]; then
  log "Cleanup unused docker images"
  docker image prune -a -f
fi

echo "You should now be able to repeat the install via oneclick_deploy.sh"
