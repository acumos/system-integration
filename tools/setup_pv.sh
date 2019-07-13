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
# What this is: script to setup host-mapped PVs under kubernetes, for a single
# node cluster (AIO)
#
# Prerequisites:
# - k8s AIO cluster deployed
# - key-based SSH setup between the workstation and k8s master node
#
# Usage: on the workstation,
#  $ bash setup_pv.sh <setup|clean|all> <path> <name> <size> <owner> [storageClassName]
#    setup|clean|all: setup, remove (including host files), or both
#    path: path of the host folder where 'name' should be created (if not existing)
#    name: name of the PV, e.g. "pv-001"
#    size: size in Gi to allocate to the PV
#    owner: owner to set for the PV folder
#    storageClassName: (optional) storageClassName to assign
#

function setup() {
  trap 'fail' ERR
  # Per https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/
  if [[ -e $path/$name ]]; then sudo rm -rf $path/$name; fi
  sudo mkdir -p $path/$name
  sudo chown $owner $path/$name
  sudo chmod 777 $path/$name
  if [[ "$(kubectl get pv $name)" == "" ]]; then
    local tmp=/tmp/$(uuidgen)
    cat <<EOF >$tmp
kind: PersistentVolume
apiVersion: v1
metadata:
  name: $name
  labels:
    type: local
spec:
  persistentVolumeReclaimPolicy: Recycle
  storageClassName: $storageClassName
  capacity:
    storage: $size
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "$path/$name"
EOF

    kubectl create -f $tmp
    kubectl get pv $name
    rm $tmp
  else
    log "WARN: PV $name already exists"
  fi
}

function clean() {
  trap 'fail' ERR
  cleanup_stuck_pvs
  reset_pv_claim=""
  clean_pv_data $name $path/$name
  if [[ "$pv_claim" != "" ]]; then
    if [[ "$pv_claim_refs" != "" ]]; then
      log "WARN: PV $name is currently claimed and in use by pods. If needed, cleanup references first, e.g. via clean.sh"
    else
      namespace=$(echo $pv_claim_refs | jq -r ".[0].namespace")
      if [[ "$(kubectl delete pvc -n $namespace $pv_claim)" ]]; then
        log "PVC $pv_claim in namespace $namespace deleted"
        kubectl delete pv $name
        log "PV $name deleted"
      else
        log "WARN: PVC $pv_claim in namespace $namespace could not be deleted"
      fi
    fi
  elif [[ "$(kubectl get pv $name)" != "" ]]; then
    kubectl delete pv $name
    log "PV $name deleted"
  fi
  if [[ -e $path/$name ]]; then
    log "Deleting host folder $path/$name"
    sudo rm -rf $path/$name
  fi
}

if [[ $# -lt 5 ]]; then
  cat <<'EOF'
 $ bash setup_pv.sh <setup|clean|all> <path> <name> <size> <owner> [storageClassName]
   setup|clean|all: setup, remove (including host files), or both
   path: path of the host folder where 'name' should be created (if not existing)
   name: name of the PV, e.g. "pv-001"
   size: size in Gi to allocate to the PV
   owner: owner to set for the PV folder
   storageClassName: (optional) storageClassName to assign
EOF
  echo "All parameters not provided"
  exit 1
fi

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
export AIO_ROOT="$(cd ../AIO; pwd -P)"
source $AIO_ROOT/utils.sh
action=$1
path=$2
name=$3
size=$4
owner=$5
storageClassName=$8

if [[ "$action" == "clean" || "$action" = "all" ]]; then clean; fi
if [[ "$action" == "setup" || "$action" = "all" ]]; then setup; fi

cd $WORK_DIR
