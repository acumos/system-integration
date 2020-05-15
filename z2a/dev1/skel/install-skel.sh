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
# Name: install-skel.sh    - skeleton for a script to install a new component
#
# Notes:
# The complete `z2a/dev1/skel` directory (including this skeleton script) should be
# copied into either the 'z2a/noncore-config' or the 'z2a/plugins-setup' directory.
#
# The newly copied 'skel' directory should be renamed appropriately.
# This file should be renamed to `install-nameOfDirectory.sh`
# A new Makefile target corresponding to the new directory name should be created
# in the 'z2a/noncore-config' or 'z2a/plugins-setup' directory.
#
# TODO: take these notes and add them to a "HOWTO.md" document

# Anchor the base directory for the util.sh helper
HERE=$(dirname $(readlink -f $0))
source $HERE/utils.sh
redirect_to $HERE/install.log

# Acumos Global Values Location
GV=$ACUMOS_GLOBAL_VALUE

# Acquire NAMESPACE and RELEASE values
NAMESPACE=$(gv_read global.namespace)
# Replace nameOfReleaseKeyValue with actual key read from global_value.yaml
RELEASE=$(gv_read global.nameOfReleaseKeyValue)

log "Installing NameOfChart ...."
# K8s config-helper Pod Deployment
helm install $RELEASE -n $NAMESPACE /LOCATION/ -f $ACUMOS_GLOBAL_VALUE

log "Waiting .... (up to 15 minutes) for pod ready status ...."
# Wait for the pods to become available
wait_for_pod_ready 900 $RELEASE
