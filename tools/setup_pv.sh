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
# $ bash setup_pv.sh <setup|clean> <master> <username> <name> <path> <size> [storageClassName]
#   setup|clean: setup or remove (including host files)
#   master: IP address or hostname of k8s master node
#   username: username on the server where the master was installed (this is
#     the user who setup the cluster, and for which key-based SSH is setup)
#   name: name of the PV, e.g. "pv-001"
#   path: path of the host folder where 'name' should be created (if not existing)
#   size: size in Gi to allocate to the PV
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
  tmp=/tmp/$(uuidgen)
  cat <<EOF >$tmp
if [[ ! \$(kubectl get pv $name) ]]; then
  if [[ ! -e $path/$name ]]; then
    sudo mkdir -p $path/$name
    sudo chown \$USER:users $path/$name
    chmod 777 $path/$name
  fi
  cat <<EOG >$name.yaml
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
EOG
  kubectl create -f $name.yaml
  kubectl get pv $name
else
  echo "PV $name already exists"
  exit 1
fi
EOF
  run_tmp
}

function clean() {
  trap 'fail' ERR
  tmp=/tmp/$(uuidgen)
  cat <<EOF >$tmp
kubectl delete pv $name
sudo rm -rf /$path/$name
EOF
  run_tmp
}

if [[ $# -lt 6 ]]; then
  cat <<'EOF'
 $ bash setup_pv.sh <setup|clean> <master> <username> <name> <path> <size> [storageClassName]
   setup|clean: setup or remove (including host files)
   master: IP address or hostname of k8s master node
   username: username on the server where the master was installed (this is
     the user who setup the cluster, and for which key-based SSH is setup)
   name: name of the PV, e.g. "pv-001"
   path: path of the host folder where 'name' should be created (if not existing)
   size: size in Gi to allocate to the PV
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
name=$4
path=$5
size=$6
storageClassName=$7

if [[ "$action" == "clean" ]]; then
  clean
else
  setup
fi

cd $WORK_DIR
