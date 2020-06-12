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
# Name: install-jupyterhub.sh - installation script for JupyterHub dependency of MLWB

# HERE
HERE=$(realpath $(dirname $0))

# Default values for Acumos JupyterHub
# Edit these values for custom values
RELEASE=mlwb-jupyterhub
# NAMESPACE=$(yq r $ACUMOS_GLOBAL_VALUE global.namespace)
MLWB_NAMESPACE=$(yq r $MLWB_GLOBAL_VALUE mlwb.namespace)

# Random 32-byte hex string generated for JupyterHub
export ACUMOS_JUPYTERHUB_HUB_TOKEN=$(openssl rand -hex 32)
export ACUMOS_JUPYTERHUB_PROXY_TOKEN=$(openssl rand -hex 32)

# Add JupyterHub repo to Helm
echo "Adding JupyterHub repo ...."
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update

# k/v map to set JupyterHub local configuration values
cat <<EOF | tee $HERE/jhub_value.yaml
hub:
  cookieSecret: "$ACUMOS_JUPYTERHUB_HUB_TOKEN"
proxy:
  secretToken: "$ACUMOS_JUPYTERHUB_PROXY_TOKEN"
prePuller:
  hook:
    enabled: false
EOF

echo "Installing JupyterHub Helm Chart ...."
helm upgrade --install $RELEASE --namespace $MLWB_NAMESPACE -f $ACUMOS_GLOBAL_VALUE \
  -f $ACUMOS_BASE/mlwb_value.yaml -f $HERE/jhub_value.yaml \
  --version=0.8.2 jupyterhub/jupyterhub

sleep 10
echo "Waiting for JupyterHub to become available ...."
# Loop for JupyterHub to become available
kubectl wait pods --for=condition=Ready --all --namespace=$MLWB_NAMESPACE --timeout=900s
for i in $(seq 1 20) ; do
  sleep 10
  # TODO: craft a query to determine the status of JupyterHub
  # kubectl exec --namespace $NAMESPACE $RELEASE
  break
  if [ $i -eq 20 ] ; then echo "\nTimeout waiting for JupyterHub to become available ...." ; exit ; fi
done
echo "\n"

echo "Determining JupyterHub Cluster setup ...."
echo "$(kubectl --namespace=$MLWB_NAMESPACE get pod)"

echo "Retrieving JupyterHub Public IP Address ...."
echo "$(kubectl --namespace=$MLWB_NAMESPACE get svc proxy-public)"

echo "JupyterHub installation complete."
echo "To use JupyterHub, enter the external IP for the proxy-public service into a browser."
echo "JupyterHub is running with a default authenticator, enter any username/password combination to enter the hub."
echo "JupyterHub proxy and hub secret tokens are contained in $HERE/jhub_value.yaml file."
