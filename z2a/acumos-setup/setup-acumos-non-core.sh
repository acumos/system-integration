#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2020 AT&T Intellectual Property & Tech Mahindra.
# All rights reserved.
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
# Name: setup-acumos-non-core.sh - setup Acumos non-core components
#
# Prerequisites:
# - Ubuntu Bionic (18.04), or Centos 7 VM
#
# - It is assumed, that the user running this script:
#   - has sudo access on the VM
#   - has successfully completed z2a phases 1a and 1b OR
#   - has a working Kubernetes environment created by other methods
#   - has sourced this script via the top-level z2a-ph2.sh script (which sets the ENV vars)
# Usage:

# Individual Acumos non-core charts
# helm install -name $CHARTNAME --namespace $NAMESPACE ./$CHARTNAME/ -f ./global_value.yaml
# where $CHARTNAME is one of the following charts

log "Installing Acumos non-core Helm charts ...."
# Install (or remove) the Acumos non-core charts, one by one in this order
log "Install Acumos non-core dependency: MariaDB ...."
helm install -name k8s-noncore-mariadb --namespace $NAMESPACE $Z2A_ACUMOS_NON_CORE/k8s-noncore-mariadb -f $Z2A_ACUMOS_BASE/global_value.yaml

log "Install Acumos non-core dependency: Nexus ...."
helm install -name k8s-noncore-nexus --namespace $NAMESPACE $Z2A_ACUMOS_NON_CORE/k8s-noncore-nexus -f $Z2A_ACUMOS_BASE/global_value.yaml

log "Install Acumos non-core dependency: Docker ...."
helm install -name k8s-noncore-docker --namespace $NAMESPACE $Z2A_ACUMOS_NON_CORE/k8s-noncore-docker -f $Z2A_ACUMOS_BASE/global_value.yaml

log "Install Acumos non-core dependency: Kong ...."
helm install -name k8s-noncore-kong --namespace $NAMESPACE $Z2A_ACUMOS_NON_CORE/k8s-noncore-kong -f $Z2A_ACUMOS_BASE/global_value.yaml

log "Install Acumos non-core dependency: Proxy ...."
helm install -name k8s-noncore-proxy --namespace $NAMESPACE $Z2A_ACUMOS_NON_CORE/k8s-noncore-proxy -f $Z2A_ACUMOS_BASE/global_value.yaml
# Install (or remove) the Acumos non-core charts for ELK, one by one in this order

log "Install Acumos non-core dependency: Elasticsearch ...."
helm install -name k8s-noncore-elasticsearch --namespace $NAMESPACE $Z2A_ACUMOS_NON_CORE/k8s-noncore-elasticsearch -f $Z2A_ACUMOS_BASE/global_value.yaml

log "Install Acumos non-core dependency: Logstash ...."
helm install -name k8s-noncore-logstash --namespace $NAMESPACE $Z2A_ACUMOS_NON_CORE/k8s-noncore-logstash -f $Z2A_ACUMOS_BASE/global_value.yaml

log "Install Acumos non-core dependency: Kibana ...."
helm install -name k8s-noncore-kibana --namespace $NAMESPACE $Z2A_ACUMOS_NON_CORE/k8s-noncore-kibana -f $Z2A_ACUMOS_BASE/global_value.yaml

log "Finished installing Acumos core Helm charts ...."
