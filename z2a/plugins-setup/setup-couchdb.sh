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

# Default values for Acoumos CouchDB
# Edit these values for custom values
RELEASE=mlwb-db

# Random UUID generated for CouchDB
Z2A_ACUMOS_COUCHDB_UUID=$(uuidgen)

log "Adding Apache CouchDB repo ...."
# Add Apache CouchDB repo to Helm
helm repo add couchdb https://apache.github.io/couchdb-helm
helm repo update

# Simple k/v map to set CouchDB configuration values
cat <<EOF | sudo tee $Z2A_ACUMOS_BASE/couchdb_value.yaml
service:
  type: NodePort
couchdbConfig:
  couchdb:
    uuid: $Z2A_ACUMOS_COUCHDB_UUID
    require_valid_user: true
EOF

log "Installing CouchDB Helm Chart ...."
helm install $RELEASE --namespace $NAMESPACE -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml -f $Z2A_ACUMOS_BASE/couchdb_value.yaml --set allowAdminParty=true couchdb/couchdb

log "Performing CouchDB Cluster setup ...."
kubectl exec --namespace $NAMESPACE $RELEASE-couchdb-0 -c couchdb -- curl -s http://127.0.0.1:5984/_cluster_setup -X POST -H "Content-Type: application/json" -d '{"action": "finish_cluster"}'

log "Retreiving CouchDB Admin secret ...."
Z2A_MLWB_COUCHDB_PASSWORD=$(kubectl get secret $RELEASE-couchdb -o go-template='{{ .data.adminPassword }}' | base64 --decode) ; save_env

log "$(CouchDB installation complete.)"
