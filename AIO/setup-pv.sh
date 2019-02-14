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
# What this is: script to setup host-mapped PVs under kubernetes or docker
#
# Prerequisites:
# - acumos-env.sh script prepared through oneclick_deploy.sh or manually, to
#   set install options (e.g. docker/k8s)
# - for k8s, k8s cluster installed using generic k8s or OpenShift
#
# Usage: intended to be called from oneclick_deploy.sh
# $ source setup-pv.sh <action> <what> <name> <size> <owner>
#   action: setup|clean
#   what: pv|pvc (setup a PV or a PVC)
#   name: unique name, to use in naming PV/PVC as $what-$ACUMOS_NAMESPACE-$name
#   size: size in Gi or Mi (e.g. 2Gi)
#   owner: host account to set as owner of the host folder
#
#   If calling directly to setup k8s PVs, use bash to run a script ala
#   cat <<'EOF' >pv.sh
#   export AIO_ROOT=$(pwd)
#   source utils.sh
#   source setup-pv.sh $1 $2 $3 $4 $5 $6
#   EOF
#   source acumos-env.sh
#   bash pv.sh setup pv logs $ACUMOS_NAMESPACE $ACUMOS_$ACUMOS_LOGS_PV_SIZE "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
#   bash pv.sh setup pv kong-db $ACUMOS_NAMESPACE $KONG_DB_PV_SIZE "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
#   bash pv.sh setup pv docker-volume $ACUMOS_NAMESPACE $DOCKER_VOLUME_PV_SIZE "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
#   bash pv.sh setup pv nexus-data $ACUMOS_NAMESPACE $NEXUS_DATA_PV_SIZE "200:$USER"
#   bash pv.sh setup pv mariadb-data $ACUMOS_NAMESPACE $MARIADB_DATA_PV_SIZE "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
#   source elk-stack/elk-env.sh
#   bash pv.sh setup pv elasticsearch-data $ACUMOS_NAMESPACE $ACUMOS_ELASTICSEARCH_DATA_PV_SIZE "1000:1000"

# Note if a PV exists, the PV will be deleted but the host foolder will be
# preserved. If needed, manually delete data before redeploying.

function log() {
  set +x
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  echo; echo "$fname:$fline ($(date)) $1"
  set -x
}

function setup_prereqs() {
  trap 'fail' ERR

  log "Basic prerequisites"
  HOST_OS=$(grep --m 1 ID /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
  if [[ "$HOST_OS" == "ubuntu" ]]; then
    sudo apt-get install -y jq
  else
    sudo yum install -y jq
  fi
}

function setup_pv() {
  trap 'fail' ERR
  path=/var/$namespace/$pv
  if [[ "$DEPLOYED_UNDER" == "docker" ]]; then
    if [[ ! -e /var/$namespace ]]; then
      log "Creating /var/$namespace as PV root folder"
      sudo mkdir /var/$namespace
      # Have to set user and group to allow pod access to PVs
      sudo chown $ACUMOS_HOST_USER:$ACUMOS_HOST_USER /var/$namespace
    fi

    if [[ ! -e $path ]]; then
      mkdir -p $path
      # TODO: remove/relax this workaround
      # Required for various components to be able to write to the PVs
      chmod 777 $path
      sudo chown $owner $path
    fi
  else
    if [[ "$ACUMOS_K8S_ROLE" == "admin" ]]; then
      log "Creating /var/$namespace as PV root folder, if needed"
      ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
        $ACUMOS_HOST_USER@$ACUMOS_DOMAIN <<EOF
set -x
if [[ ! -e /var/$namespace ]]; then
  sudo mkdir /var/$namespace
  sudo chown $ACUMOS_HOST_USER:$ACUMOS_HOST_USER /var/$namespace
fi
if [[ ! -e $path ]]; then
  mkdir -p $path
  chmod 777 $path
  sudo chown $owner $path
fi
EOF

    # Per https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/
    if [[ ! $(kubectl get pv $name) ]]; then
      mkdir -p /tmp/$namespace/yaml
      log "Creating kubernetes PV $name"
      cat <<EOF >/tmp/$namespace/yaml/$name.yaml
kind: PersistentVolume
apiVersion: v1
metadata:
  name: $name
spec:
  storageClassName: $namespace
  capacity:
    storage: $size
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  hostPath:
    path: "$path"
EOF

        kubectl create -f /tmp/$namespace/yaml/$name.yaml
        kubectl get pv $name
      else
        log "PV $name exists, not recreating it"
      fi
    fi
  fi
}

function setup_pvc() {
  trap 'fail' ERR
  if [[ ! $(kubectl get pvc -n $namespace $name) ]]; then
    mkdir -p /tmp/$namespace/yaml
    log "Creating PVC $name"
    # Add volumeName: to ensure the PVC selects a specific volume as data
    # may be pre-configured there
    cat <<EOF >/tmp/$namespace/yaml/$name.yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: $name
spec:
  storageClassName: $namespace
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: $size
  volumeName: "$pv_name"
EOF

    kubectl create -n $namespace -f /tmp/$namespace/yaml/$name.yaml
    kubectl get pvc -n $namespace $name
  else
    log "$name exists, not recreating it"
  fi
}

function clean() {
  trap 'fail' ERR
  if [[ "$what" == "pvc" ]]; then
    if [[ $(kubectl get namespaces) ]]; then
      log "Deleting $what-$namespace-$pv"
      if [[ $(kubectl delete pvc -n $namespace $name) ]]; then
        while $(kubectl get pvc -n $namespace $name); do
          log "Waiting 10 seconds for PVC $name to be deleted"
          sleep 10
        done
      fi
    fi
  else
    if [[ $(kubectl get namespaces $namespace) && "$ACUMOS_K8S_ROLE" == "admin" ]]; then
      log "Deleting $what-$namespace-$pv"
      if [[ $(kubectl delete pv $name) ]]; then
        while $(kubectl get pv $name); do
          log "Waiting 10 seconds for PV $name to be deleted"
          sleep 10
        done
      fi
    fi
    if [[ -e /var/$namespace/$pv ]]; then
      log "Deleting host folder /var/$namespace/$pv"
      sudo rm -rf /var/$namespace/$pv
    fi
  fi
}

action=$1
what=$2
pv=$3
namespace=$4
size=$5
owner=$6

if [[ "$what" == "pv" ]]; then name="pv-$namespace-$pv"
else
  name="pvc-$namespace-$pv"
  pv_name="pv-$namespace-$pv"
fi

setup_prereqs
if [[ "$action" == "clean" ]]; then
  clean
else
  if [[ "$what" == "pv" ]]; then
    setup_pv
  else
    setup_pvc
  fi
fi
