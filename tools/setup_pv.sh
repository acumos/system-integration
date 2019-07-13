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
# $ bash setup_pv.sh <setup|clean|all> <master> <username> <path> <name> <size> <owner> [storageClassName]
#   setup|clean\all: setup, remove (including host files), or both
#   master: IP address or hostname of k8s master node
#   username: username on the server where the master was installed (this is
#     the user who setup the cluster, and for which key-based SSH is setup)
#   path: path of the host folder where 'name' should be created (if not existing)
#   name: name of the PV, e.g. "pv-001"
#   size: size in Gi to allocate to the PV
#   owner: owner to set for the PV folder
#   storageClassName: storageClassName to assign
#

function run_tmp() {
  trap 'fail' ERR
  if [[ "$master" != "$HOSTNAME"* ]]; then
    ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
      $username@$master 'bash -s' < $tmp
  else
    bash $tmp
  fi
  rm $tmp
}

function setup() {
  trap 'fail' ERR
  # Per https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/
  if [[ "$(kubectl get pv $name)" == "" ]]; then
    local tmp=/tmp/$(uuidgen)
    cat <<EOF >$tmp
if [[ -e $path/$name ]]; then rm -rf $path/$name; fi
sudo mkdir -p $path/$name
sudo chown $owner $path/$name
sudo chmod 777 $path/$name
EOF
    run_tmp

    cat <<EOF >$tmp.yaml
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
    path: "/$path/$name"
EOF
    kubectl create -f $tmp.yaml
    kubectl get pv $name
    rm $tmp.yaml
  else
    log "PV $name already exists"
  fi
}

function clean() {
  trap 'fail' ERR
  if [[ "$(kubectl get pv $name)" != "" ]]; then
    if [[ "$(kubectl get pv $name -o json | jq -r '.spec.claimRef.name')" != "null" ]]; then
      kubectl patch pv $name --type json -p '[{ "op": "remove", "path": "/spec/claimRef" }]'
    fi
    if [[ "$(kubectl get pv $name)" != "" ]]; then
      kubectl delete pv $name
    fi
  fi
  local tmp=/tmp/$(uuidgen)
  cat <<EOF >$tmp
sudo rm -rf /$path/$name
EOF
  run_tmp
}

if [[ $# -lt 6 ]]; then
  cat <<'EOF'
 $ bash setup_pv.sh <setup|clean|all> <master> <username> <path> <name> <size> <owner> [storageClassName]
   setup|clean|all: setup, remove (including host files), or both
   master: IP address or hostname of k8s master node
   username: username on the server where the master was installed (this is
     the user who setup the cluster, and for which key-based SSH is setup)
   path: path of the host folder where 'name' should be created (if not existing)
   name: name of the PV, e.g. "pv-001"
   size: size in Gi to allocate to the PV
   owner: owner to set for the PV folder
   storageClassName: storageClassName to assign
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
master=$2
username=$3
path=$4
name=$5
size=$6
owner=$7
storageClassName=$8

if [[ "$action" == "clean" || "$action" = "all" ]]; then clean; fi
if [[ "$action" == "setup" || "$action" = "all" ]]; then setup; fi

cd $WORK_DIR
