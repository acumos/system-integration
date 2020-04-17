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
# Name: z2a-ph1a.sh - z2a Phase 1a setup script
#
# Prerequisites:
# - Ubuntu Xenial (16.04), Bionic (18.04), or Centos 7 VM
#
# - It is assumed, that the user running this script:
#		- has sudo access on the VM
#
# Usage:

# Create user environment
for v in $(set | grep ^Z2A_) ; do
	unset ${v%=**}
done
# Anchor Z2A_BASE value
Z2A_BASE=$(realpath $(dirname $0))
# Z2A_* environment values
Z2A_ACUMOS_BASE=$(realpath $Z2A_BASE/../helm-charts)
Z2A_ACUMOS_CORE=$Z2A_ACUMOS_BASE/acumos
Z2A_ACUMOS_DEPENDENCIES=$Z2A_ACUMOS_BASE/dependencies
Z2A_ACUMOS_NON_CORE=$Z2A_ACUMOS_BASE/dependencies/k8s-noncore-chart/charts
# Create clean working copy of global_value.yaml to work with
mv $Z2A_ACUMOS_BASE/global_value.yaml $Z2A_ACUMOS_BASE/global_value.yaml.orig
egrep -v '^\s*#' $Z2A_ACUMOS_BASE/global_value.yaml.orig > $Z2A_ACUMOS_BASE/global_value.yaml
# Z2A K8S environment values
Z2A_K8S_CLUSTERNAME=$(yq r $Z2A_ACUMOS_BASE/global_value.yaml global.clusterName)
Z2A_K8S_NAMESPACE=$(yq r $Z2A_ACUMOS_BASE/global_value.yaml global.namespace)
# Source the z2a utils file
source $Z2A_BASE/z2a-utils.sh
# Save initial user environment
save_env
# Redirect stdout/stderr to log file
redirect_to $Z2A_BASE/z2a-ph1a-install.log
# Exit with an error on any non-zero return code
trap 'fail' ERR

# Distribution ID
rhel || ubuntu || { log "Sorry, only Centos/RHEL or Ubuntu are currently supported." ; exit 1 ; }

log "Starting Phase 1a (Distribution Specific Setup) installation ...."
# Installation - Phase 1a Distribution-specific setup
source $Z2A_BASE/distro-setup/setup-distro.sh

log "Starting Phase 1a (Docker Community Edition) installation ...."
# Installation - Phase 1a  Docker Community Edition
source $Z2A_BASE/distro-setup/setup-docker.sh