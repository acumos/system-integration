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
# What this is: script to setup the MariaDB service for Acumos, using Helm chart
# https://github.com/helm/charts/tree/master/stable/mariadb
#
# Prerequisites:
# - k8s cluster deployed with Helm
# - Available PVs with at least 10GiB disk and default storage class
# - If you want to specify environment values, set and export them prior
#   to running this script, e.g. by creating a script named mariadb_env.sh.
#   See setup_mariadb_env.sh for the default values.
#
# Usage: from the k8s master or a host setup use kubectl/helm remotely
# $ bash setup_mariadb.sh <AIO_ROOT> <mariadb_host> <k8s_dist>
#   AIO_ROOT: path to AIO folder where environment files are
#   mariadb_host: hostname or FQDN of mariadb service. Must be resolvable locally
#     or thru DNS. Can be the hostname of the k8s master node.
#   k8s_dist: kubernetes distribtion (generic|openshift)
#
# - To use a MariaDB service deployed with this script for an Acumos platform,
#   use the variables saved in mariadb_env.sh to configure the platform, e.g.
#   for an AIO (oneclick) install, copy mariadb_env.sh to the AIO folder prior
#   to deploying.
#
# TODO:
# - Verify upgrade and redeploy
# - Verify use under OpenShift
# - Add ingress controller and drop use of NodePort
# - Fix issues in upstream chart (templates/initialization-configmap.yaml)

set -x

function mariadb_fail() {
  set +x
  trap - ERR
  reason="$1"
  if [[ "$1" == "" ]]; then reason="unknown failure at $fname $fline"; fi
  log "$reason"
  sedi 's/DEPLOY_RESULT=.*/DEPLOY_RESULT=fail/' mariadb_env.sh
  sedi "s~FAIL_REASON=.*~FAIL_REASON=$reason~" mariadb_env.sh
  exit 1
}

function mariadb_customize_values() {
  trap 'mariadb_fail' ERR
  rm -rf /tmp/charts
  git clone https://github.com/helm/charts.git /tmp/charts
  cd /tmp/charts/stable/mariadb
  sedi 's/type: ClusterIP/type: NodePort/' values.yaml
  sedi 's/# nodePort:/nodePort:/' values.yaml
  sedi 's/#   master: 30001/   master: 30001/' values.yaml
  sedi "s/  password:\$/  password: $ACUMOS_MARIADB_PASSWORD/" values.yaml
  sedi "s/  password:\$/  password: $ACUMOS_MARIADB_USER_PASSWORD/" values.yaml
  sedi "s/  user:/  user: $ACUMOS_MARIADB_USER/" values.yaml
  sedi "s/  name: my_database/  name: $ACUMOS_CDS_DB/" values.yaml
}

function mariadb_customize_sql() {
  trap 'mariadb_fail' ERR
  cd /tmp/charts/stable/mariadb
  # Issue bug to https://github.com/helm/charts/tree/master/stable/mariadb
  sedi 's/{{ template "master.fullname" . }}/mariadb/' \
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

function mariadb_deploy_chart() {
  trap 'mariadb_fail' ERR
  if [[ ! $(helm upgrade --install mariadb --namespace $ACUMOS_MARIADB_NAMESPACE --values $WORK_DIR/values.yaml $1) ]]; then
    echo "MariaDB install via Helm failed"
    exit 1
  fi
}

function mariadb_clean() {
  trap 'mariadb_fail' ERR
  if [[ $(helm list mariadb) ]]; then
    helm delete --purge mariadb
  fi
  delete_namespace $ACUMOS_MARIADB_NAMESPACE
  # The PVC sometimes takes longer to be deleted than the namespace, probably
  # due to PV datta recycle operations; this can block later re-creation...
  delete_pvc mariadb-data $ACUMOS_MARIADB_NAMESPACE
}

function mariadb_setup() {
  trap 'mariadb_fail' ERR
  local WORK_DIR=$(pwd)

  log "Create the values.yaml input for the Helm chart"
  # have to break out hierarchial values for master... does not work as a.b.c
  cat <<EOF >values.yaml
service.type: NodePort
image.tag: 10.2.22
rootUser.password: $ACUMOS_MARIADB_PASSWORD
rootUser.forcePassword: true
db.user: $ACUMOS_MARIADB_USER
db.password: $ACUMOS_MARIADB_USER_PASSWORD
db.name: $ACUMOS_CDS_DB
replication:
  enabled: false
master:
  persistence:
    enabled: true
    storageClass: $ACUMOS_MARIADB_NAMESPACE
    existingClaim: $MARIADB_DATA_PVC_NAME
EOF

  # TODO: Address issue: Helm chart deployed but statefulset fails. Detected by
  # the following in 'oc describe statefulset -n acumos-mariadb mariadb'
  # create Pod mariadb-0 in StatefulSet mariadb failed error:
  # pods "mariadb-0" is forbidden: unable to validate against any security
  # context constraint: [fsGroup: Invalid value: []int64{1001}: 1001 is not an
  # allowed group spec.containers[0].securityContext.securityContext.runAsUser:
  # Invalid value: 1001: must be in the ranges: [1000160000, 1000169999]]
  if [[ "$K8S_DIST" == "openshift" ]]; then
    log "Add for openshift: 'securityContext.enabled: false'"
    cat <<EOF >>values.yaml
securityContext:
  enabled: false
EOF
  fi

  cat values.yaml

  mariadb_customize_values

  base="https://raw.githubusercontent.com/acumos/common-dataservice/master/cmn-data-svc-server/db-scripts"
  if [ "$ACUMOS_CDS_PREVIOUS_VERSION" == "" ]; then
    echo "Using database script for CDS version $ACUMOS_CDS_VERSION"
    sql="cmn-data-svc-ddl-dml-mysql-$ACUMOS_CDS_VERSION.sql"
    mariadb_customize_sql
  elif [ "$ACUMOS_CDS_PREVIOUS_VERSION" != "$ACUMOS_CDS_VERSION" ]; then
    log "Using upgrade script for CDS version $ACUMOS_CDS_PREVIOUS_VERSION to $ACUMOS_CDS_VERSION"
    sql="cds-mysql-upgrade-$ACUMOS_CDS_PREVIOUS_VERSION-to-$ACUMOS_CDS_VERSION.sql"
    mariadb_customize_sql
  else
    echo "Redeploying with existing database version - no DB scripts required."
  fi

  create_namespace $ACUMOS_MARIADB_NAMESPACE
  setup_pvc mariadb-data $ACUMOS_MARIADB_NAMESPACE $MARIADB_DATA_PV_SIZE
  cd /tmp/charts/stable/mariadb
  mariadb_deploy_chart '.'
  wait_running mariadb $ACUMOS_MARIADB_NAMESPACE

  cd $WORK_DIR
}


if [[ $# -lt 3 ]]; then
  echo <<'EOF'
Usage: from the k8s master or a host setup use kubectl/helm remotely
  $ bash setup_mariadb.sh <AIO_ROOT> <mariadb_host> <k8s_dist>
    AIO_ROOT: path to AIO folder where environment files are
    mariadb_host: hostname or FQDN of mariadb service. Must be resolvable locally
      or thru DNS. Can be the hostname of the k8s master node.
    k8s_dist: kubernetes distribtion (generic|openshift)
EOF
  echo "All parameters not provided"
  exit 1
fi

WORK_DIR=$(pwd)
export AIO_ROOT=$1
export ACUMOS_MARIADB_HOST=$2
export DEPLOYED_UNDER=k8s
export K8S_DIST=$3
source $AIO_ROOT/utils.sh
cd $AIO_ROOT/../charts/mariadb

if [[ -e mariadb_env.sh ]]; then
  log "Using prepared mariadb_env.sh for customized environment values"
  source mariadb_env.sh
fi

set_k8s_env

source setup_mariadb_env.sh
mariadb_clean
mariadb_setup
# Prevent ACUMOS_CDS_VERSION in mariadb-env fron overriding acumos_env.sh,
# since it may be updated later by acumos_env.sh
sedi "s/ACUMOS_CDS_VERSION=/#ACUMOS_CDS_VERSION=/" mariadb_env.sh
cd $WORK_DIR
