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
# Name: install-skel.sh    - script skeleton to aid in installing a new component
#
# Version:
#
# 2020-05-21 - add step-wise notes section
# 2020-05-19 - add block for local-overrides
#            - add section for new repos
# 2020-05-15 - add explanations (and clarify a couple of items)
# 2020-05-14 - initial version
#
# Notes:
#
# Step 1
# The complete `z2a/dev1/skel` directory (including this skeleton script) should be
# copied into either the 'z2a/noncore-config' or the 'z2a/plugins-setup' directory.
# Step 2
# The newly copied 'skel' directory should be renamed appropriately. `<name-of-new-plugin>`
# Step 3:
# The `z2a/plugins/<name-of-new-plugin>/install-skel.sh` file should be renamed to `install-nameOfDirectory.sh`
# Step 4
# A new Makefile target corresponding to the new directory name should be created
# in the `z2a/noncore-config` or `z2a/plugins-setup` directory.
#
# TODO: Take these notes and add them to a "HOWTO.md" document (In progress)
#

# Anchor the base directory for the util.sh helper
HERE=$(dirname $(readlink -f $0))
# Makefile will copy the utils.sh.tpl template into $HERE
source $HERE/utils.sh
# redirect_to the install logfile $HERE
redirect_to $HERE/install.log

# ACUMOS_GLOBAL_VALUE should be picked up from 0-kind/0a-env.sh script
# Acumos global value file (global_value.yaml) location
GV=$ACUMOS_GLOBAL_VALUE

# Acquire NAMESPACE and RELEASE values via the gv_read function (see utils.sh)
# Note: this value HAS to be valid
NAMESPACE=$(gv_read global.namespace)
# Replace nameOfReleaseKeyValue with an actual `plugin` key name added to global_value.yaml
# TODO: how to add key/values to global_value.yaml?
RELEASE=$(gv_read global.nameOfReleaseKeyValue)

# Uncomment the following 3 lines to add a new Helm Chart repo here
# echo "Adding <Name Of> repo ...."
# helm repo add name https://location-of.repo.com
# helm repo update

# k/v map for local override values should be added here
cat <<EOF | tee $HERE/local-override-values.yaml
EOF

log "Installing NameOfChart ...."
# use Helm to deploy the chart using this command format
helm install $RELEASE -n $NAMESPACE /LOCATION/ -f $GV -f local-override-values.yaml

# If pods need time to reach a ready state, uncomment the 'log' and 'wait_for_pod_ready lines below
# log "Waiting .... (up to 15 minutes) for pod ready status ...."
# Wait for the pods to become available - 15 minutes (900 seconds) is the default
# wait_for_pod_ready 900 $RELEASE
