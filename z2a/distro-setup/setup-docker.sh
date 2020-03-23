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
# Name: setup-docker.sh - script to install Docker Community Edition
#
# Dependencies: assumes that setup-distro.sh has been executed.

# Remove old Docker versions (just in case) ; ignore if package does not exist
log "Removing old Docker versions ...."
rhel && sudo yum remove docker docker-client docker-client-latest \
	docker-common docker-latest docker-latest-logrotate docker-logrotate \
	docker-engine || true
ubuntu && sudo apt-get remove docker docker-engine docker.io containerd runc || true

# Setup Docker-CE repo
log "Setting up Docker-CE repositories ...."
rhel && sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
ubuntu && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - \
	&& sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

log "Setting up Docker Community-Edition ...."
# Install Docker-CE
rhel && sudo yum -y install docker-ce docker-ce-cli containerd.io
ubuntu && sudo apt-get -y update && sudo apt-get -y install docker-ce docker-ce-cli containerd.io

log "Starting Docker service ...."
# Start docker service
sudo systemctl enable docker.service
sudo systemctl start docker.service

log "Adding USER to docker group ...."
# Add default user to the 'docker' group
sudo usermod -aG docker $USER

# We need to log out and back in at this point.
log "Docker has been installed on this host."
log "Host / VM preparation has been completed."
log "Please log out of this session and log back in to continue."
log "Please navigate to the script directory and run z2a_ph2.sh."