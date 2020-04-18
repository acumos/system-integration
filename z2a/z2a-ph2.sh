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
# Name: z2a-ph2.sh - z2a Phase 2 setup script (Acumos)
#
# Prerequisites:
# - Ubuntu Xenial (16.04), Bionic (18.04), or Centos 7 VM
#
# - It is assumed, that the user running this script:
#		- has sudo access on the VM
#		- has successfully ran the accompanying z2a_ph1a.sh
#			and z2a_ph1b.sh setup scripts
#
# Usage:

# Anchor Z2A_BASE
Z2A_BASE=$(realpath $(dirname $0))
# Source the z2a utils file
source $Z2A_BASE/z2a-utils.sh
# Load user environment
load_env
# Exit with an error on any non-zero return code
trap 'fail' ERR

redirect_to /dev/tty

NAMESPACE=$Z2A_K8S_NAMESPACE
<<<<<<< HEAD
Z2A_ACUMOS_BASE=$(realpath $Z2A_BASE/../helm-charts)
Z2A_ACUMOS_CORE=$Z2A_ACUMOS_BASE/acumos
Z2A_ACUMOS_DEPENDENCIES=$Z2A_ACUMOS_BASE/dependencies
Z2A_ACUMOS_NON_CORE=$Z2A_ACUMOS_BASE/dependencies/k8s-noncore-chart/charts
save_env

log "Starting Phase 2a (Acumos non-core dependencies) installation ...."
# Installation - Phase 2a - Acumos non-core dependencies
source $Z2A_BASE/acumos-setup/setup-acumos-non-core.sh

log "Starting Phase 2b (Acumos core) installation ...."
# Installation - Phase 2b - Acumos core
=======

# Test to ensure that all Pods are running before proceeding
wait_for_pods 180   # seconds

echo "Starting Phase 2 (Acumos non-core dependencies) installation ...."
# Installation - Phase 2 - Acumos non-core dependencies
source $Z2A_BASE/acumos-setup/setup-acumos-noncore.sh

echo "Starting Phase 2 (Acumos core) installation ...."
# Installation - Phase 2 - Acumos core
<<<<<<< HEAD
>>>>>>> ebd8949d19b4aa7c652add32fe1721b43bb54242
source $Z2A_BASE/acumos-setup/setup-acumos-core.sh
=======
source $Z2A_BASE/acumos-setup/setup-acumos-core.sh

echo "Please check the status of the K8s pods at this time .... "
echo "Please ensure that all pods are in a 'Running' status before proceeding ...."
>>>>>>> 6695cd52b37b146d178b9e86c03c43354a3e2a3d
