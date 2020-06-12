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
# Name: 1-acumos.sh - z2a 1-acumos.sh script (Acumos)
#
# Prerequisites:
# - Ubuntu Xenial (16.04), Bionic (18.04), or Centos 7 VM
#
# - It is assumed, that the user running this script:
#		- has sudo access on their VM and
#		- has executed the 0-kind/*.sh setup scripts to create a standalone k8s cluster
#   - OR - has executed the 0a-env.sh script and provided their own k8s cluster
#

# Anchor Z2A_BASE
HERE=$(realpath $(dirname $0))
Z2A_BASE=$(realpath $HERE/..)
# Source the z2a utils file
source $Z2A_BASE/z2a-utils.sh
# Load user environment
load_env
# Exit with an error on any non-zero return code
# trap 'fail' ERR
set -e

#TODO: fix this
# redirect_to /dev/tty

# Global Values
export ACUMOS_GLOBAL_VALUE=$Z2A_ACUMOS_BASE/global_value.yaml
NAMESPACE=$Z2A_K8S_NAMESPACE

echo "Starting 1-acumos installation ...."
echo "Creating k8s namespace : name = $Z2A_K8S_NAMESPACE"
# Create an namespace on the k8s cluster
# - for `Flow 1` - default z2a `kind` cluster namespace: z2a-test
# - for `Flow 2` - Bring-Your-Own-Cluster`, see: global_value.yaml (global.namespace)
#TODO: add logic to determine if this namespace exists
kubectl create namespace $Z2A_K8S_NAMESPACE

echo "Starting 1-acumos (Acumos noncore dependencies) installation ...."
# Installation - Acumos noncore dependencies
# Install the Acumos noncore charts, one by one in this order (configuration is performed by default)

echo "Install Acumos noncore dependency: Kubernetes ingress ...."
#TODO: add logic to determine which Flow this is
(cd $Z2A_BASE/noncore-config/ ; make ingress)

echo "Install Acumos noncore dependency: Kubernetes config helper ...."
#TODO: add logic to determine which Flow this is
(cd $Z2A_BASE/noncore-config/ ; make config-helper)

echo "Install Acumos noncore dependency: Sonatype Nexus (Oteemo Chart) ...."
(cd $Z2A_BASE/noncore-config/ ; make nexus)

echo "Install Acumos noncore dependency: MariaDB (Bitnami Chart) ...."
(cd $Z2A_BASE/noncore-config/ ; make mariadb-cds)

# Kong is currently disabled. To enable Kong, uncomment the following lines.
# echo "Install Acumos noncore dependency: Kong & PostgreSQL (Bitnami Charts) ...."
# (cd $Z2A_BASE/noncore-config/ ; make kong)

# The following charts are installed  directly via a helm deployment command
# NOTE: *this is a comment* helm install -name $CHARTNAME --namespace $NAMESPACE <PATH>$CHARTNAME -f <PATH>global_value.yaml

echo "Install Acumos noncore dependency: Docker ...."
helm install -name k8s-noncore-docker --namespace $NAMESPACE $Z2A_ACUMOS_NON_CORE/k8s-noncore-docker -f $Z2A_ACUMOS_BASE/global_value.yaml

echo "Install Acumos noncore dependency: Proxy ...."
helm install -name k8s-noncore-proxy --namespace $NAMESPACE $Z2A_ACUMOS_NON_CORE/k8s-noncore-proxy -f $Z2A_ACUMOS_BASE/global_value.yaml

# Install (or remove) the Acumos noncore charts for ELK, one by one in this order
echo "Install Acumos noncore dependency: Elasticsearch ...."
helm install -name k8s-noncore-elasticsearch --namespace $NAMESPACE $Z2A_ACUMOS_NON_CORE/k8s-noncore-elasticsearch -f $Z2A_ACUMOS_BASE/global_value.yaml

echo "Install Acumos noncore dependency: Logstash ...."
helm install -name k8s-noncore-logstash --namespace $NAMESPACE $Z2A_ACUMOS_NON_CORE/k8s-noncore-logstash -f $Z2A_ACUMOS_BASE/global_value.yaml

echo "Install Acumos noncore dependency: Kibana ...."
helm install -name k8s-noncore-kibana --namespace $NAMESPACE $Z2A_ACUMOS_NON_CORE/k8s-noncore-kibana -f $Z2A_ACUMOS_BASE/global_value.yaml

echo "Finished installing Acumos noncore dependencies ...."

echo "Starting 1-acumos (Acumos core) installation ...."
# Installation - Acumos core
# Install (or remove) the Acumos core charts, one by one in this order

echo "Installing Acumos prerequisite chart ...."
helm install -name prerequisite --namespace $NAMESPACE $Z2A_ACUMOS_CORE/prerequisite/ -f $Z2A_ACUMOS_BASE/global_value.yaml

echo "Installing Acumos Common Data Services chart ...."
helm install -name common-data-svc --namespace $NAMESPACE $Z2A_ACUMOS_CORE/common-data-svc/ -f $Z2A_ACUMOS_BASE/global_value.yaml

echo "Installing Acumos Portal BE chart ...."
helm install -name portal-be --namespace $NAMESPACE $Z2A_ACUMOS_CORE/portal-be/ -f $Z2A_ACUMOS_BASE/global_value.yaml

echo "Installing Acumos Portal FE chart ...."
helm install -name portal-fe --namespace $NAMESPACE $Z2A_ACUMOS_CORE/portal-fe/ -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml

echo "Installing Acumos Onboarding chart ...."
helm install -name onboarding --namespace $NAMESPACE $Z2A_ACUMOS_CORE/onboarding/ -f $Z2A_ACUMOS_BASE/global_value.yaml

echo "Installing Acumos Microservice Generation chart ...."
helm install -name microservice-generation --namespace $NAMESPACE $Z2A_ACUMOS_CORE/microservice-generation/ -f $Z2A_ACUMOS_BASE/global_value.yaml

echo "Installing Acumos DS Composition Engine chart ...."
helm install -name ds-compositionengine --namespace $NAMESPACE $Z2A_ACUMOS_CORE/ds-compositionengine/ -f $Z2A_ACUMOS_BASE/global_value.yaml

echo "Installing Acumos Federation chart ...."
helm install -name federation --namespace $NAMESPACE $Z2A_ACUMOS_CORE/federation/ -f $Z2A_ACUMOS_BASE/global_value.yaml

echo "Finished installing Acumos core Helm charts ...."

echo "Please check the status of the Kubernetes pods at this time ...."
echo "Please ensure that all pods are in a 'Running' status before proceeding ...."
echo "Once all pods become available, access the Acumos Portal by pointing your browser to:  http://localhost:8085 ...."
echo "Note: 'localhost' is localhost on the VM running Acumos (not your desktop).  May require a SSH tunnel to access! "
