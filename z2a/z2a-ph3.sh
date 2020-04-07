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
# Name: z2a-ph3.sh - z2a Phase 3 setup script (MLWB)
#
# Prerequisites:
# - Ubuntu Xenial (16.04), Bionic (18.04), or Centos 7 VM
#
# - It is assumed, that the user running this script:
#		- has sudo access on the VM
#		- has successfully completed the Phase 2 (Acumos) installation OR
#			has installed Acumos by other methods
#
# Usage:

# Anchor Z2A_BASE
Z2A_BASE=$(realpath $(dirname $0))
# Source the z2a utils file
source $Z2A_BASE/utils.sh
# Load user environment
load_env
# Redirect stdout/stderrr to log file
redirect_to z2a-ph3-install
# Exit with an error on any non-zero return code
trap 'fail' ERR

NAMESPACE=$Z2A_K8S_NAMESPACE

log "Starting Phase 3 (MLWB dependencies) installation ..."
# Installation - Phase 3a - MLWB plugin dependencies
source $Z2A_BASE/plugins-setup/setup-couchdb.sh
source $Z2A_BASE/plugins-setup/setup-jupyterhub.sh
source $Z2A_BASE/plugins-setup/setup-nifi.sh

log "Starting Phase 3 (MLWB) installation ..."
# Installation - Phase 3b - MLWB plugin
source $Z2A_BASE/plugins-setup/setup-mlwb.sh
