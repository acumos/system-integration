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
#.   what: pv|pvc (setup a PV or a PVC)
#.   namespace: for k8s, namespace to create the PVC under
#.   size: size in Gi or Mi (e.g. 2Gi)
#.   owner: host account to set as owner of the host folder
#.
#. Note if a PV exists, the PV will be deleted but the host foolder will be
#. preserved. If needed, manually delete data before redeploying.

function setup_pv() {
  trap 'fail' ERR
  mkdir -p /tmp/$ACUMOS_NAMESPACE/yaml
  if [[ "$ACUMOS_SETUP_PVS" == "true" ]]; then
    # Per https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/
    if [[ ! -e /var/$ACUMOS_NAMESPACE ]]; then
      log "Creating /var/$ACUMOS_NAMESPACE as PV root folder"
      sudo mkdir /var/$ACUMOS_NAMESPACE
      # Have to set user and group to allow pod access to PVs
      sudo chown $USER:$USER /var/$ACUMOS_NAMESPACE
    fi

    if [[ "$DEPLOYED_UNDER" = "docker" ]]; then
      log "Creating folder for host-path docker volume $pv"
      path="/var/$ACUMOS_NAMESPACE/$pv"
      if [[ ! -e $path ]]; then
        mkdir -p $path
        # TODO: remove/relax this workaround
        # Required for various components to be able to write to the PVs
        chmod 777 $path
      fi
    else
      log "Creating kubernetes PV pv-$ACUMOS_NAMESPACE-$pv"
      path="/var/$ACUMOS_NAMESPACE/$pv"
      if [[ ! -e $path ]]; then
        mkdir $path
        # TODO: remove/relax this workaround
        # TODO: some writes fail in Centos without this
        chmod 777 $path
        sudo chown $owner $path
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
  fi
}

function setup_pvc() {
  trap 'fail' ERR
  mkdir -p /tmp/$ACUMOS_NAMESPACE/yaml
  log "Creating PVC pvc-$ACUMOS_NAMESPACE-$pv"
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
  trap 'fail' ERR
  if [[ "$DEPLOYED_UNDER" = "k8s" ]]; then
    log "Deleting $what-$ACUMOS_NAMESPACE-$pv"
    if [[ "$what" == "pvc" ]]; then
      if [[ $($k8s_cmd delete pvc -n $ACUMOS_NAMESPACE pvc-$ACUMOS_NAMESPACE-$pv) ]]; then
        wait_until_fail "$k8s_cmd get pvc -n $ACUMOS_NAMESPACE pvc-$ACUMOS_NAMESPACE-$pv"
      fi
    else
      if [[ "$ACUMOS_SETUP_PVS" == "true" ]]; then
        if [[ $($k8s_cmd delete pv pv-$ACUMOS_NAMESPACE-$pv) ]]; then
          wait_until_fail "$k8s_cmd get pv pv-$ACUMOS_NAMESPACE-$pv"
        fi
      fi
    fi
    if [[ -e /tmp/$ACUMOS_NAMESPACE/yaml/p*-$ACUMOS_NAMESPACE-$pv.yaml ]]; then
      rm /tmp/$ACUMOS_NAMESPACE/yaml/p*-$ACUMOS_NAMESPACE-$pv.yaml
    fi
  fi
  if [[ "$ACUMOS_SETUP_PVS" == "true" ]]; then
    if [[ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]]; then
      if [[ -e /var/$ACUMOS_NAMESPACE/$pv ]]; then
        log "Deleting host folder /var/$ACUMOS_NAMESPACE/$pv"
        sudo rm -rf /var/$ACUMOS_NAMESPACE/$pv
      fi
    else
      log "Not deleting /var/$ACUMOS_NAMESPACE/$pv: platform is being redeployed"
    fi
  fi
}

set -x
source $AIO_ROOT/acumos-env.sh
source $AIO_ROOT/utils.sh
trap 'fail' ERR

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
