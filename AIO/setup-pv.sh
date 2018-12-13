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
#. What this is: script to setup host-mapped PVs under kubernetes or docker
#.
#. Prerequisites:
#. - acumos-env.sh script prepared through oneclick_deploy.sh or manually, to
#.   set install options (e.g. docker/k8s)
#. - for k8s, k8s cluster installed using generic k8s or OpenShift
#.
#. Usage: on the k8s master
#. $ bash setup-pv.sh <action> <what> <namespace> <pv> <size> <owner>
#.   action: setup|clean
#.   what: pv|pvc
#.   namespace: for k8s, namespace to create the PVC under
#.   size: size in Gi or Mi (e.g. 2Gi)
#.   owner: host account to set as owner of the host folder
#.

function setup_pv() {
  # Per https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/
  mkdir -p /tmp/$ACUMOS_NAMESPACE/yaml
  if [[ ! -e /var/$ACUMOS_NAMESPACE ]]; then
    log "Create /var/$ACUMOS_NAMESPACE as PV root folder"
    sudo mkdir /var/$ACUMOS_NAMESPACE
    # Have to set user and group to allow pod access to PVs
    sudo chown $USER:$USER /var/$ACUMOS_NAMESPACE
  fi

  if [[ "$DEPLOYED_UNDER" = "docker" ]]; then
    log "Create folder for host-path docker volume $pv"
    path="/var/$ACUMOS_NAMESPACE/$pv"
    if [[ ! -e $path ]]; then
      mkdir -p $path
      # TODO: remove/relax this workaround
      # Required for various components to be able to write to the PVs
      chmod 777 $path
    fi
  else
    log "Create kubernetes PV pv-$ACUMOS_NAMESPACE-$pv"
    path="/var/$ACUMOS_NAMESPACE/$pv"
    if [[ ! -e $path ]]; then
      mkdir $path
      sudo chown $owner $path
      # TODO: remove/relax this workaround
      # TODO: some writes fail in Centos without this
      chmod 777 $path
    fi
    cat <<EOF >/tmp/$ACUMOS_NAMESPACE/yaml/pv-$ACUMOS_NAMESPACE-$pv.yaml
kind: PersistentVolume
apiVersion: v1
metadata:
  name: pv-$ACUMOS_NAMESPACE-$pv
spec:
  storageClassName: $ACUMOS_NAMESPACE
  capacity:
    storage: $size
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: "$path"
EOF

      $k8s_cmd create -f /tmp/$ACUMOS_NAMESPACE/yaml/pv-$ACUMOS_NAMESPACE-$pv.yaml
      $k8s_cmd get pv pv-$ACUMOS_NAMESPACE-$pv
  fi
}

function setup_pvc() {
  log "Create PVC pvc-$ACUMOS_NAMESPACE-$pv"
  # Add volumeName: to ensure the PVC selects a specific volume as data
  # may be pre-configured there
  cat <<EOF >/tmp/$ACUMOS_NAMESPACE/yaml/pvc-$ACUMOS_NAMESPACE-$pv.yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: pvc-$ACUMOS_NAMESPACE-$pv
spec:
  storageClassName: $ACUMOS_NAMESPACE
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: $size
  volumeName: "pv-$ACUMOS_NAMESPACE-$pv"
EOF

  $k8s_cmd create -n $ACUMOS_NAMESPACE -f /tmp/$ACUMOS_NAMESPACE/yaml/pvc-$ACUMOS_NAMESPACE-$pv.yaml
  $k8s_cmd get pvc -n $ACUMOS_NAMESPACE pvc-$ACUMOS_NAMESPACE-$pv
}

function clean() {
  if [[ "$DEPLOYED_UNDER" = "k8s" ]]; then
    if [[ "$what" == "pvc" ]]; then
      $k8s_cmd delete pvc -n $ACUMOS_NAMESPACE pvc-$ACUMOS_NAMESPACE-$pv
      rm /tmp/$ACUMOS_NAMESPACE/yaml/pvc-$ACUMOS_NAMESPACE-$pv.yaml
    else
      $k8s_cmd delete pv pv-$ACUMOS_NAMESPACE-$pv
      rm /tmp/$ACUMOS_NAMESPACE/yaml/pv-$ACUMOS_NAMESPACE-$pv.yaml
    fi
  fi
  sudo rm -rf /var/$ACUMOS_NAMESPACE/$pv
}

source $AIO_ROOT/acumos-env.sh
source $AIO_ROOT/utils.sh

action=$1
what=$2
pv=$3
size=$4
owner=$5

if [[ "$action" == "clean" ]]; then
  clean
else
  if [[ "$what" == "pv" ]]; then
    setup_pv
  else
    setup_pvc
  fi
fi
