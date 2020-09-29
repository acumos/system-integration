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
# Name: install-license-usage-manager.sh
# - helper script to install License Usage Manager

# Anchor the base directory for the util.sh helper
HERE=$(dirname $(readlink -f $0))
source $HERE/utils.sh
setup_logging

# Default values for License Usage Manager (LUM)
# Edit these values for custom values
NAMESPACE=$(gv_read global.namespace)
RELEASE=license-usage-manager

# Create local values.yaml file on-the-fly
cat <<EOF | tee $HERE/values.yaml
imagetag: 1.3.4
EOF

log "Downloading LUM (License Usage Manager) Chart ...."
mkdir -p license-usage-manager
curl -s -L "https://gerrit.acumos.org/r/gitweb?p=license-usage-manager.git;a=snapshot;h=HEAD;sf=tgz" \
  | tar xz -C license-usage-manager --strip-components=1 --wildcards license-usage-manager-*/

# yq commands to update PostgreSQL
yq w -i license-usage-manager/lum-helm/requirements.yaml dependencies[0].version 9.4.1
yq w -i license-usage-manager/lum-helm/requirements.yaml dependencies[0].repository https://charts.bitnami.com/bitnami

# Remove stale requirements.lock file
rm -f $HERE/license-usage-manager/lum-helm/requirements.lock

# Use helm to deploy the PostgreSQL chart
# helm dependency update ./license-usage-manager/lum-helm
helm dependency build ./license-usage-manager/lum-helm
helm install $RELEASE -n $NAMESPACE $HERE/license-usage-manager/lum-helm -f $HERE/values.yaml

# Write out logfile name
success
