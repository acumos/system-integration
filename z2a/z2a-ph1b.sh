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
# Name: z2a-ph1b.sh - z2a Phase 1b setup script
#
# Prerequisites:
# - Ubuntu Xenial (16.04), Bionic (18.04), or Centos 7 VM
#
# - It is assumed, that the user running this script:
#		- has sudo access on the VM
#		- has successfully ran the accompanying z2a_ph1a.sh script
#   - has logged out and back in to a new session
#
# Usage:

# Determine if the end-user is actually a member of the Docker group
# We can not proceed past here without the user being in the Docker group
id -nG | grep -q docker || {
  echo "User is not a member of the docker group."
  echo "Please log out and log back in to a new session."
  exit 1
}

# Anchor Z2A_BASE
Z2A_BASE=$(realpath $(dirname $0))
# Source the z2a utils file
source $Z2A_BASE/z2a-utils.sh
# Load user environment
load_env
# Redirect stdout/stderr to log file
redirect_to z2a-ph1b-install
redirect_to $Z2A_BASE/z2a-ph1b-install.log
# Exit with an error on any non-zero return code
trap 'fail' ERR

log "Starting Phase 1b (k8s, helm, kind) installation ..."
# Installation - Phase 1b - kubectl, helm and kind
source $Z2A_BASE/distro-setup/setup-k8s-helm-kind.sh
source $Z2A_BASE/distro-setup/setup-z2a-values.sh
source $Z2A_BASE/distro-setup/setup-k8s-helm-kind.sh
source $Z2A_BASE/distro-setup/setup-k8s-helpers.sh

log "Completed Phase 1b (k8s, helm, kind) installation ..."
log "Please check the status of the K8s pods at this time. "
log "Please ensure that all pods are in a 'Running' status before proceeding with Phase 2 installation."
