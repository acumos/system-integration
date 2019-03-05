#!/bin/bash
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2019 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
# What this is: Environment file for ELK stack "beats" depoyment for Acumos.
# Prerequisites:
# - Ubuntu Xenial or Centos 7 server
# Usage:
# - Intended to be called from setup-beats.sh
# - Customize the values here for your needs.
#

# images
export ACUMOS_FILEBEAT_IMAGE=$ACUMOS_STAGING/acumos-filebeat:2.0.7
export ACUMOS_METRICBEAT_IMAGE=$ACUMOS_STAGING/acumos-metricbeat:2.0.7

# Component options
export ACUMOS_FILEBEAT_PORT=8099
export ACUMOS_METRICBEAT_PORT=8098
