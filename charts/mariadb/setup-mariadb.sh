#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2019 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
# What this is: script to setup the MariaDB service for Acumos, using Helm
#
# Prerequisites:
# - k8s cluster deployed with Helm
# - Available PVs with at least 10GiB disk and default storage class
# - If you want to specify values for the following, set and export them prior
#   to running this script, e.g. by creating a script named mariadb-env.sh.
#   Note: the script will assign default values to any of the following that
#   are not set, and save the set of variables as mariadb-env.sh.
#   ACUMOS_MARIADB_NAMESPACE=<namespace, a DNS-compatible string)>
#   ACUMOS_CDS_VERSION=<CDS database version, e.g. 1.18>
#   ACUMOS_CDS_PREVIOUS_VERSION=<previous CDS version; set when
#     redeploying/upgrading with an existing database
#   ACUMOS_CDS_DB=<CDS database name to use>
#   ACUMOS_MARIADB_PASSWORD=<MariaDB root user password>
#   ACUMOS_MARIADB_USER=<MariaDB user to create>
#   ACUMOS_MARIADB_USER_PASSWORD=<MariaDB user password>
#
# How to use: from the k8s master or a host setup use kubectl/helm remotely
# $ bash setup-mariadb.sh
#
# - To use a MariaDB service deployed with this script for an Acumos platform,
#   use the variables saved in mariadb-env.sh to configure the platform, e.g.
#   for an AIO (oneclick) install, copy mariadb-env.sh to the AIO folder prior
#   to deploying.
#
# TODO:
# - Verify upgrade and redeploy
# - Verify use under OpenShift
#    if [[ "$K8S_DIST" == "openshift" ]]; then
#      log "Workaround variation in OpenShift for external access to mariadb"
#      sed -i -- 's/<ACUMOS_HOST>/172.17.0.1/' kubernetes/mariadb-deployment.yaml
#    fi
# - Add ingress controller and drop use of NodePort
# - Fix issues in upstream chart (templates/initialization-configmap.yaml)

set -x

function mariadb_fail() {
  set +x
  trap - ERR
  reason="$1"
  if [[ "$1" == "" ]]; then reason="unknown failure at $fname $fline"; fi
  log "$reason"
  sed -i -- 's/DEPLOY_RESULT=.*/DEPLOY_RESULT=fail/' mariadb-env.sh
  sed -i -- "s~FAIL_REASON=.*~FAIL_REASON=$reason~" mariadb-env.sh
  exit 1
}

function log() {
  set +x
  fname=$(caller 0 | awk '{print $2}')
  fline=$(caller 0 | awk '{print $1}')
  echo; echo "$fname:$fline ($(date)) $1"
  set -x
}

function customize_values() {
  trap 'mariadb_fail' ERR
  rm -rf /tmp/charts
  git clone https://github.com/helm/charts.git /tmp/charts
  cd /tmp/charts/stable/mariadb
  sed -i -- 's/type: ClusterIP/type: NodePort/' values.yaml
  sed -i -- 's/# nodePort:/nodePort:/' values.yaml
  sed -i -- 's/#   master: 30001/   master: 30001/' values.yaml
  sed -i -- "s/  password:\$/  password: $ACUMOS_MARIADB_PASSWORD/" values.yaml
  sed -i -- "s/  password:\$/  password: $ACUMOS_MARIADB_USER_PASSWORD/" values.yaml
  sed -i -- "s/  user:/  user: $ACUMOS_MARIADB_USER/" values.yaml
  sed -i -- "s/  name: my_database/  name: $ACUMOS_CDS_DB/" values.yaml
}

function customize_sql() {
  trap 'mariadb_fail' ERR
  cd /tmp/charts/stable/mariadb
  # Issue bug to https://github.com/helm/charts/tree/master/stable/mariadb
  sed -i -- 's/{{ template "master.fullname" . }}/mariadb/' \
    templates/initialization-configmap.yaml
  cd files/docker-entrypoint-initdb.d
  wget -O /tmp/$sql $base/$sql
  if [[ ! -e /tmp/$sql ]]; then
    echo "No available CDS script $sql"
    exit 1
  fi
  echo "use $ACUMOS_CDS_DB;" >$sql
  cat /tmp/$sql >>$sql

  cat <<EOF >user.sql
USE $ACUMOS_CDS_DB;
GRANT ALL PRIVILEGES ON $ACUMOS_CDS_DB.* TO "$ACUMOS_MARIADB_USER"@'%' IDENTIFIED BY "$ACUMOS_MARIADB_USER_PASSWORD";
EOF
}

function deploy_chart() {
  trap 'mariadb_fail' ERR
  if [[ ! $(helm upgrade --install mariadb --namespace $ACUMOS_MARIADB_NAMESPACE --values $WORK_DIR/values.yaml $1) ]]; then
    echo "MariaDB install via Helm failed"
    exit 1
  fi
}

function clean() {
  trap 'mariadb_fail' ERR
  if [[ $(helm list mariadb) ]]; then
    helm delete --purge mariadb
  fi
  if [[ $(kubectl get namespace $ACUMOS_MARIADB_NAMESPACE) ]]; then
    kubectl delete namespace $ACUMOS_MARIADB_NAMESPACE
    while $(kubectl get namespace $ACUMOS_MARIADB_NAMESPACE) ; do
      log "Waiting for namespace $ACUMOS_MARIADB_NAMESPACE to be deleted"
      sleep 10
    done
    while $(kubectl get pvc -n $ACUMOS_MARIADB_NAMESPACE $MARIADB_DATA_PVC_NAME) ; do
      log "Waiting for PVCs in namespace $ACUMOS_MARIADB_NAMESPACE to be deleted"
      sleep 10
    done
  fi
}

function setup() {
  trap 'mariadb_fail' ERR
  local WORK_DIR=$(pwd)

  # have to break out hierarchial values for master... does not work as a.b.c
  cat <<EOF >values.yaml
service.type: NodePort
image.tag: 10.2.22
rootUser.password: $ACUMOS_MARIADB_PASSWORD
rootUser.forcePassword: true
db.user: $ACUMOS_MARIADB_USER
db.password: $ACUMOS_MARIADB_USER_PASSWORD
db.name: $ACUMOS_CDS_DB
master:
  persistence:
    enabled: true
    storageClass: $ACUMOS_MARIADB_NAMESPACE
    existingClaim: $MARIADB_DATA_PVC_NAME
replication:
  enabled: false
EOF

  customize_values

  base="https://raw.githubusercontent.com/acumos/common-dataservice/master/cmn-data-svc-server/db-scripts"
  if [ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]; then
    echo "Using database script for CDS version $ACUMOS_CDS_VERSION"
    sql="cmn-data-svc-ddl-dml-mysql-$ACUMOS_CDS_VERSION.sql"
    customize_sql
  elif [ "$ACUMOS_CDS_PREVIOUS_VERSION" != "$ACUMOS_CDS_VERSION" ]; then
    log "Using upgrade script for CDS version $ACUMOS_CDS_PREVIOUS_VERSION to $ACUMOS_CDS_VERSION"
    sql="cds-mysql-upgrade-$ACUMOS_CDS_PREVIOUS_VERSION-to-$ACUMOS_CDS_VERSION.sql"
    customize_sql
  else
    echo "Redeploying with existing database version - no DB scripts required."
  fi

  if [[ ! $(kubectl get namespace $ACUMOS_MARIADB_NAMESPACE) ]]; then
    kubectl create namespace $ACUMOS_MARIADB_NAMESPACE
  fi

  log "Creating PVC $MARIADB_DATA_PVC_NAME"
  mkdir -p /tmp/$ACUMOS_MARIADB_NAMESPACE/yaml
  # Add volumeName: to ensure the PVC selects a specific volume as data
  # may be pre-configured there
  cat <<EOF >/tmp/$ACUMOS_MARIADB_NAMESPACE/yaml/$MARIADB_DATA_PVC_NAME.yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: $MARIADB_DATA_PVC_NAME
spec:
  storageClassName: $ACUMOS_MARIADB_NAMESPACE
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: $MARIADB_DATA_PV_SIZE
  volumeName: "$MARIADB_DATA_PV_NAME"
EOF

  kubectl create -n $ACUMOS_MARIADB_NAMESPACE -f \
    /tmp/$ACUMOS_MARIADB_NAMESPACE/yaml/$MARIADB_DATA_PVC_NAME.yaml
  kubectl get pvc -n $ACUMOS_MARIADB_NAMESPACE $MARIADB_DATA_PVC_NAME

  cd /tmp/charts/stable/mariadb
  deploy_chart '.'

  cd $WORK_DIR
}

if [[ ! -e mariadb-env.sh ]]; then
  source setup-mariadb-env.sh
fi

clean
setup
