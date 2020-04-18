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
# Name: setup-acumos-core.sh - setup Acumos core components
#
# Prerequisites:
<<<<<<< HEAD
# - Ubuntu Xenial (16.04), Bionic (18.04), or Centos 7 VM
=======
# - Ubuntu Bionic (18.04), or Centos 7 VM
>>>>>>> ebd8949d19b4aa7c652add32fe1721b43bb54242
#
# - It is assumed, that the user running this script:
#   - has sudo access on the VM
#   - has successfully completed z2a phases 1a and 1b OR
<<<<<<< HEAD
#     has a working Kubernetes environment created by other methods
=======
#   - has a working Kubernetes environment created by other methods
<<<<<<< HEAD
#   - has sourced this script via the top-level z2a-ph2.sh script (which sets the ENV vars)
>>>>>>> ebd8949d19b4aa7c652add32fe1721b43bb54242
#		- has successfully succesfully installed the Acumos non-core dependencies
=======
#   - has sourced this script via the top-level z2a script (which sets the ENV vars)
#		- has successfully installed and configured the Acumos non-core dependencies
>>>>>>> 6695cd52b37b146d178b9e86c03c43354a3e2a3d
#
# Usage:

# Individual Acumos core charts
# helm install -name $CHARTNAME --namespace $NAMESPACE <PATH>$CHARTNAME -f <PATH>global_value.yaml
# where $CHARTNAME is one of the following charts
# - prerequisite
# - common-data-svc
# - portal
# - onboarding
# - microservice-generation
# - ds-compositionengine
# - federation

log "Installing Acumos core Helm charts ...."
# Install (or remove) the Acumos non-core charts, one by one in this order
<<<<<<< HEAD
helm install -name prerequisite --namespace $NAMESPACE $Z2A_ACUMOS_CORE/prerequisite/ -f $Z2A_ACUMOS_BASE/global_value.yaml
helm install -name common-data-svc --namespace $NAMESPACE $Z2A_ACUMOS_CORE/common-data-svc/ -f $Z2A_ACUMOS_BASE/global_value.yaml
helm install -name portal --namespace $NAMESPACE $Z2A_ACUMOS_CORE/portal/ -f $Z2A_ACUMOS_BASE/global_value.yaml
helm install -name onboarding --namespace $NAMESPACE $Z2A_ACUMOS_CORE/onboarding/ -f $Z2A_ACUMOS_BASE/global_value.yaml
helm install -name microservice-generation --namespace $NAMESPACE $Z2A_ACUMOS_CORE/microservice-generation/ -f $Z2A_ACUMOS_BASE/global_value.yaml
helm install -name ds-compositionengine --namespace $NAMESPACE $Z2A_ACUMOS_CORE/ds-compositionengine/ -f $Z2A_ACUMOS_BASE/global_value.yaml
helm install -name federation --namespace $NAMESPACE $Z2A_ACUMOS_CORE/federation/ -f $Z2A_ACUMOS_BASE/global_value.yaml

log "Finshed installing Acumos core Helm charts ...."
=======
log "Installing Acumos prerequisite chart ...."
helm install -name prerequisite --namespace $NAMESPACE $Z2A_ACUMOS_CORE/prerequisite/ -f $Z2A_ACUMOS_BASE/global_value.yaml

log "Installing Acumos Common Data Services chart ...."
helm install -name common-data-svc --namespace $NAMESPACE $Z2A_ACUMOS_CORE/common-data-svc/ -f $Z2A_ACUMOS_BASE/global_value.yaml

log "Installing Acumos Portal chart ...."
helm install -name portal --namespace $NAMESPACE $Z2A_ACUMOS_CORE/portal/ -f $Z2A_ACUMOS_BASE/global_value.yaml

log "Installing Acumos Onboarding chart ...."
helm install -name onboarding --namespace $NAMESPACE $Z2A_ACUMOS_CORE/onboarding/ -f $Z2A_ACUMOS_BASE/global_value.yaml

log "Installing Acumos Microservice Generation chart ...."
helm install -name microservice-generation --namespace $NAMESPACE $Z2A_ACUMOS_CORE/microservice-generation/ -f $Z2A_ACUMOS_BASE/global_value.yaml

log "Installing Acumos DS Composition Engine chart ...."
helm install -name ds-compositionengine --namespace $NAMESPACE $Z2A_ACUMOS_CORE/ds-compositionengine/ -f $Z2A_ACUMOS_BASE/global_value.yaml

log "Installing Acumos Federation chart ...."
helm install -name federation --namespace $NAMESPACE $Z2A_ACUMOS_CORE/federation/ -f $Z2A_ACUMOS_BASE/global_value.yaml

log "Finished installing Acumos core Helm charts ...."
>>>>>>> ebd8949d19b4aa7c652add32fe1721b43bb54242
