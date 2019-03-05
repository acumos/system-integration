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
# What this is:
# Deployment script for the Acumos ELK-stack "beats" components under docker.
# Sets environment variables needed by docker-compose in all-in-one environment
# then invokes docker-compose with the command-line arguments.
#
# Usage:
# - bash docker-compose.sh <beat> [options]
#   beat: filebeat|metricbeat
#   options: optional parameters to docker-compose.
#

trap - ERR

cmd="$2 $3 $4 $5"
cd docker
docker-compose -f acumos/$1.yml $cmd
cd ..

trap 'fail' ERR
