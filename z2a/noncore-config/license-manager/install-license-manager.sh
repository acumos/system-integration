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
# Name: install-license-manager.sh  - helper script to install License Manager

# Anchor the base directory for the util.sh helper
HERE=$(dirname $(readlink -f $0))
source $HERE/utils.sh
setup_logging

# Default values for License Manager
# Edit these values for custom values
NAMESPACE=$(gv_read global.namespace)

# Create local values.yaml file on-the-fly
SECRET=$(gv_read global.ingress.tlsSecretName)
cat <<EOF | tee $HERE/values.yaml
ingress:
  hosts:
    - ""
  tls:
    - secretName: "$SECRET"
EOF

log "Downloading LM (License Manager) Chart ...."
mkdir -p license-manager
curl -L "https://gerrit.acumos.org/r/gitweb?p=license-manager.git;a=snapshot;h=HEAD;sf=tgz" \
  | tar xz -C license-manager --strip-components=1 --wildcards license-manager-*/

# Use helm to deploy license-profile-editor helm chart
RELEASE=license-profile-editor
helm install $RELEASE -n $NAMESPACE $HERE/license-manager/license-profile-editor-helm-chart -f $HERE/values.yaml

# Use helm to deploy license-rtu-editor helm chart
RELEASE=license-rtu-editor
helm install $RELEASE -n $NAMESPACE $HERE/license-manager/license-rtu-editor-helm-chart -f $HERE/values.yaml

# Write out logfile name
success
