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
# - If you are deploying MariaDB in standalone mode (i.e. running this script
#   directly), create a mariadb_env.sh file including at least a value for
#     export ACUMOS_MARIADB_DOMAIN=<DNS or /etc/hosts-resolvable domain name>
#
# Usage: from the k8s master or a host setup use kubectl/helm remotely
# $ bash setup_mariadb.sh <clean|prep|setup|all> <mariadb_host> <k8s_dist>
#   clean|prep|setup|all: action to execute
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

function mariadb_customize_values() {
  trap 'fail' ERR
  rm -rf /tmp/charts
  git clone https://github.com/helm/charts.git /tmp/charts
  # mariadb 10.2+ breaks insertion of rows with non-default values.
  # Set sql_mode="" (remove the default strict mode as of 10.2)
  # See https://mariadb.com/kb/en/library/sql-mode/
  # If this fails to work at some point, checkout known working version
  # git checkout c4cc463af34266b703d4e952f100fb6051d2ee76
  # Commit https://github.com/helm/charts/commit/85a033f50d6027fa8113c3e93c2c0a6723ab426a#diff-f1be10c8c772fb7b13251e5510c3044e
  sed -i -- '/    \[mysqld\]/a\ \ \ \ sql_mode=""' /tmp/charts/stable/mariadb/values.yaml
  sed -i -- 's/type: ClusterIP/type: NodePort/' /tmp/charts/stable/mariadb/values.yaml
  sed -i -- 's/# nodePort:/nodePort:/' /tmp/charts/stable/mariadb/values.yaml
  sed -i -- "s/#   master: 30001/   master: $ACUMOS_MARIADB_NODEPORT/" /tmp/charts/stable/mariadb/values.yaml
  sed -i -- "s/  password:\$/  password: $ACUMOS_MARIADB_PASSWORD/" /tmp/charts/stable/mariadb/values.yaml
  sed -i -- "s/  password:\$/  password: $ACUMOS_MARIADB_USER_PASSWORD/" /tmp/charts/stable/mariadb/values.yaml
  sed -i -- "s/  user:/  user: $ACUMOS_MARIADB_USER/" /tmp/charts/stable/mariadb/values.yaml
  sed -i -- "s/  name: my_database/  name: $ACUMOS_CDS_DB/" /tmp/charts/stable/mariadb/values.yaml
}

function mariadb_customize_sql() {
  trap 'fail' ERR
  # Issue bug to https://github.com/helm/charts/tree/master/stable/mariadb
  sed -i -- 's/{{ template "master.fullname" . }}/mariadb/' \
    /tmp/charts/stable/mariadb/templates/initialization-configmap.yaml
}

function mariadb_deploy_chart() {
  trap 'fail' ERR
  helm repo update
  if [[ ! $(helm upgrade --install $ACUMOS_MARIADB_NAMESPACE-mariadb --namespace $ACUMOS_MARIADB_NAMESPACE --values $WORK_DIR/values.yaml $1) ]]; then
    echo "MariaDB install via Helm failed"
    exit 1
  fi
}

function mariadb_clean() {
  trap 'fail' ERR
  if [[ $(helm delete --purge $ACUMOS_MARIADB_NAMESPACE-mariadb) ]]; then
    log "Helm release $ACUMOS_MARIADB_NAMESPACE-mariadb deleted"
  fi
  log "Delete all MariaDB resources"
  wait_until_notfound "kubectl get pods -n $ACUMOS_MARIADB_NAMESPACE" mariadb
  delete_pvc $ACUMOS_MARIADB_NAMESPACE $MARIADB_DATA_PVC_NAME
}

function mariadb_prep() {
  trap 'fail' ERR
  verify_ubuntu_or_centos
  if [[ "$ACUMOS_CREATE_PVS" == "true" ]]; then
    bash $AIO_ROOT/../tools/setup_pv.sh all /mnt/$ACUMOS_MARIADB_NAMESPACE \
      $MARIADB_DATA_PV_NAME $MARIADB_DATA_PV_SIZE \
      "$ACUMOS_HOST_USER:$ACUMOS_HOST_USER"
  fi
  bash $AIO_ROOT/../tools/setup_mariadb_client.sh
  create_namespace $ACUMOS_MARIADB_NAMESPACE
}

function mariadb_setup() {
  trap 'fail' ERR
  local WORK_DIR=$(pwd)

  log "Create the values.yaml input for the Helm chart"
  # have to break out hierarchial values for master... does not work as a.b.c
  cat <<EOF >values.yaml
volumePermissions.enabled: true
service.type: NodePort
image.tag: 10.2.22
image.debug: true
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
    log "Add for openshift: 'securityContext.enabled: true and user/group'"
    get_openshift_uid $ACUMOS_MARIADB_NAMESPACE
    update_mariadb_env ACUMOS_MARIADB_RUNASUSER $OPENSHIFT_UID force
    cat <<EOF >>values.yaml
securityContext:
  enabled: true
  fsGroup: $ACUMOS_MARIADB_RUNASUSER
  runAsUser: $ACUMOS_MARIADB_RUNASUSER
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

  setup_pvc $ACUMOS_MARIADB_NAMESPACE $MARIADB_DATA_PVC_NAME $MARIADB_DATA_PV_NAME \
    $MARIADB_DATA_PV_SIZE
  mariadb_deploy_chart /tmp/charts/stable/mariadb/.

  local t=0
  while [[ "$(helm list $ACUMOS_MARIADB_NAMESPACE-mariadb --output json | jq -r '.Releases[0].Status')" != "DEPLOYED" ]]; do
    if [[ $t -eq $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      fail "$ACUMOS_MARIADB_NAMESPACE-mariadb is not ready after $ACUMOS_SUCCESS_WAIT_TIME seconds"
    fi
    log "$ACUMOS_MARIADB_NAMESPACE-mariadb Helm release is not yet Deployed, waiting 10 seconds"
    sleep 10
    t=$((t+10))
  done

  wait_running mariadb $ACUMOS_MARIADB_NAMESPACE

  ACUMOS_MARIADB_NODEPORT=$(kubectl get services -n $ACUMOS_MARIADB_NAMESPACE $ACUMOS_MARIADB_NAMESPACE-mariadb -o json | jq -r '.spec.ports[0].nodePort')
  update_mariadb_env ACUMOS_MARIADB_NODEPORT $ACUMOS_MARIADB_NODEPORT force

  local t=0
  log "Wait for mariadb server to accept connections"
  port=$ACUMOS_MARIADB_PORT
  host=$ACUMOS_MARIADB_HOST
  if [[ "$ACUMOS_DEPLOY_AS_POD" == "false" || "$ACUMOS_MARIADB_HOST" != "$ACUMOS_INTERNAL_MARIADB_HOST" ]]; then
    host=$ACUMOS_MARIADB_DOMAIN
    port=$ACUMOS_MARIADB_NODEPORT
  fi

  while ! nc -z $host $port ; do
    log "Mariadb is not yet listening at $host:$port"
    sleep 10
    t=$((t+10))
    if [[ $t -gt $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      fail "MariaDB failed to respond after $ACUMOS_SUCCESS_WAIT_TIME seconds"
    fi
  done
  while ! mysql -h $host -P $port --user=root \
  --password=$ACUMOS_MARIADB_PASSWORD -e "SHOW DATABASES;" ; do
    log "Mariadb server is not yet accepting connections from $ACUMOS_MARIADB_ADMIN_HOST"
    sleep 10
    t=$((t+10))
    if [[ $t -gt $ACUMOS_SUCCESS_WAIT_TIME ]]; then
      fail "MariaDB failed to respond after $ACUMOS_SUCCESS_WAIT_TIME seconds"
    fi
  done

  log "Initialize Acumos database"
  # CDS 2.2 added portal assets (images) to the DDL so we can't use a configmap
  # anymore (DDL > 1MB)
  bash $AIO_ROOT/setup_acumosdb.sh
  update_acumos_env ACUMOS_SETUP_DB false force
}

if [[ $# -lt 1 ]]; then usage=yes;
elif [[ "$1" != 'clean' && $# -lt 3 ]]; then usage=yes
fi

if [[ "$usage" == "yes" ]]; then
  cat <<'EOF'
Usage: from the k8s master or a host setup use kubectl/helm remotely
  $ bash setup_mariadb.sh <clean|prep|setup|all> <mariadb_host> <k8s_dist>
    clean|prep|setup|all: action to execute
    mariadb_host: hostname or FQDN of mariadb service. Must be resolvable locally
      or thru DNS. Can be the hostname of the k8s master node.
    k8s_dist: kubernetes distribtion (generic|openshift)
EOF
  echo "All parameters not provided"
  exit 1
fi

set -x
trap 'fail' ERR
WORK_DIR=$(pwd)
cd $(dirname "$0")
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ../../AIO; pwd -P)"; fi
source $AIO_ROOT/utils.sh
source $AIO_ROOT/acumos_env.sh
if [[ -z "$AIO_ROOT" ]]; then export AIO_ROOT="$(cd ../../AIO; pwd -P)"; fi
action=$1
export ACUMOS_MARIADB_HOST=$2
export DEPLOYED_UNDER=k8s
export K8S_DIST=$3

if [[ -e mariadb_env.sh ]]; then
  log "Using prepared mariadb_env.sh for customized environment values"
  source mariadb_env.sh
fi

source setup_mariadb_env.sh
cp mariadb_env.sh $AIO_ROOT/.
if [[ "$action" == "clean" || "$action" == "all" ]]; then mariadb_clean; fi
if [[ "$action" == "prep" || "$action" == "all" ]]; then mariadb_prep; fi
if [[ "$action" == "setup" || "$action" == "all" ]]; then mariadb_setup; fi
# Copy any updates from the above functions
cp mariadb_env.sh $AIO_ROOT/.
cd $WORK_DIR
