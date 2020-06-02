#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2019 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
# Name: install-couchdb.sh - installation script for CouchDB dependency for MLWB

# HERE
HERE=$(realpath $(dirname $0))

# Default values for Acumos CouchDB
# Edit these values for custom values
RELEASE=mlwbdb
MLWB_NAMESPACE=$(yq r $MLWB_GLOBAL_VALUE mlwb.namespace)
# NAMESPACE=$(yq r $ACUMOS_GLOBAL_VALUE global.namespace)

# Random UUID generated for CouchDB
ACUMOS_COUCHDB_UUID=$(uuidgen)

echo "Adding Apache CouchDB repo ...."
# Add Apache CouchDB repo to Helm
helm repo add couchdb https://apache.github.io/couchdb-helm
helm repo update

# k/v map to set CouchDB local configuration values
cat <<EOF | tee $HERE/couchdb_value.yaml
service:
  type: NodePort
couchdbConfig:
  couchdb:
    uuid: $ACUMOS_COUCHDB_UUID
    require_valid_user: true
EOF

echo "Installing CouchDB Helm Chart ...."
helm install $RELEASE --namespace $MLWB_NAMESPACE -f $ACUMOS_GLOBAL_VALUE -f $ACUMOS_BASE/mlwb_value.yaml -f $HERE/couchdb_value.yaml --set allowAdminParty=true couchdb/couchdb

echo "Waiting for pods to become ready ...."
# Wait for pods to become available
kubectl wait pods --for=condition=Ready --all --namespace=$MLWB_NAMESPACE --timeout=900s

echo "Waiting for CouchDB instance to become ready ...."
# Loop for CouchDB to become available"
for i in $(seq 1 20) ; do
  sleep 10
  kubectl exec --namespace $MLWB_NAMESPACE $RELEASE-couchdb-0 -c couchdb -- curl -s http://127.0.0.1:5984/ && break
  if [ $i -eq 20 ] ; then echo "\nTimeout waiting for CouchDB to become available ...." ; exit ; fi
done
echo "\n"

echo "Performing CouchDB Cluster setup ...."
kubectl exec --namespace $MLWB_NAMESPACE $RELEASE-couchdb-0 -c couchdb -- curl -s http://127.0.0.1:5984/_cluster_setup -X POST -H "Content-Type: application/json" -d '{"action": "finish_cluster"}'

# TODO: write this value back to mlwb_value.yaml
echo "Retrieving CouchDB Admin secret ...."
MLWB_COUCHDB_PASSWORD=$(kubectl get secret --namespace $MLWB_NAMESPACE $RELEASE-couchdb -o go-template='{{ .data.adminPassword }}' | base64 --decode)

echo "CouchDB installation complete."
