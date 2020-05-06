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

# Default values for Acoumos JupyterHub
# Edit these values for custom values
export RELEASE=mlwb-jupyterhub

# Random 32-byte hex string generated for JupyterHub
export Z2A_ACUMOS_JUPYTERHUB_HUB_TOKEN=$(openssl rand -hex 32)
export Z2A_ACUMOS_JUPYTERHUB_PROXY_TOKEN=$(openssl rand -hex 32)

# Add JupyterHub repo to Helm
log "Adding JupyterHub repo ...."
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update

# k/v map to set JupyterHub local configuration values
cat <<EOF | tee $Z2A_ACUMOS_BASE/jhub_value.yaml
hub:
  cookieSecret: "$Z2A_ACUMOS_JUPYTERHUB_HUB_TOKEN"
proxy:
  secretToken: "$Z2A_ACUMOS_JUPYTERHUB_PROXY_TOKEN"
EOF

log "Installing JupyterHub Helm Chart ...."
helm upgrade --install $RELEASE --namespace $NAMESPACE -f $Z2A_ACUMOS_BASE/global_value.yaml -f $Z2A_ACUMOS_BASE/mlwb_value.yaml -f $Z2A_ACUMOS_BASE/jhub_value.yaml --version=0.8.2 jupyterhub/jupyterhub

log "Waiting for JupyterHub to become available ...."
# Loop for JupyterHub to become available
for i in $(seq 1 20) ; do
  sleep 10
  logc .
  TODO: craft a query to determine the status of JupyterHub
  # kubectl exec --namespace $NAMESPACE $RELEASE
  if [ $i -eq 20 ] ; then log "\nTimeout waiting for JupyterHub to become available ...." ; exit ; fi
done
log "\n"

log "Determining JupyterHub Cluster setup ...."
log "$(kubectl --namespace=$NAMESPACE get pod)"

log "Retrieving JupyterHub Public IP Address ...."
log "$(kubectl --namespace=$NAMESPACE get svc proxy-public)"

log "JupyterHub installation complete."
log "To use JupyterHub, enter the external IP for the proxy-public service into a browser."
log "JupyterHub is running with a default authenticator, enter any username/password combination to enter the hub."
log "JupyterHub proxy and hub secret tokens are contained in $Z2A_ACUMOS_BASE/jhub_value.yaml file."
