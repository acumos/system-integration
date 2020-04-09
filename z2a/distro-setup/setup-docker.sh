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

log "Removing old Docker versions ...."
# Remove old Docker versions (just in case) ; ignore if package does not exist
rhel && sudo yum remove docker docker-client docker-client-latest \
	docker-common docker-latest docker-latest-logrotate docker-logrotate \
	docker-engine || true
ubuntu && sudo apt-get remove docker docker-engine docker.io containerd runc || true

log "Setting up Docker-CE repositories ...."
# Setup Docker-CE repo
rhel && sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
ubuntu && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - \
	&& sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

log "Setting up Docker Community-Edition ...."
# Install Docker-CE
rhel && sudo yum -y install docker-ce docker-ce-cli containerd.io
ubuntu && sudo apt-get -y update && sudo apt-get -y install docker-ce docker-ce-cli containerd.io

log "Creating /etc/docker directory ...."
## Create /etc/docker directory.
sudo mkdir -p /etc/docker

log "Creating /etc/docker/daemon.json file ...."
# Setup Docker daemon.
rhel && {
	cat <<EOF | sudo tee /etc/docker/daemon.json
{
	"exec-opts": ["native.cgroupdriver=systemd"],
	"log-driver": "json-file",
"log-opts": {
  	"max-size": "100m"
	},
	"storage-driver": "overlay2",
	"storage-opts": ["overlay2.override_kernel_check=true"]
	}
EOF
}

ubuntu && {
	cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
	}
EOF
}

log "Creating the systemd docker.service directory ...."
# Create the systemd docker.service directory
sudo mkdir -p /etc/systemd/system/docker.service.d

# Setup Docker daemon proxy entries.
PROXY_CONF=$Z2A_BASE/distro-setup/proxy.txt
[[ -f $PROXY_CONF ]] && {
	PROXY=$(<$PROXY_CONF) ;
	log "Configuring /etc/systemd/system/docker.service.d/http-proxy.conf file ...."
	cat <<EOF | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=http://$PROXY"
Environment="HTTPS_PROXY=https://$PROXY"
Environment="NO_PROXY=127.0.0.1,localhost,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
EOF
}

log "Starting Docker service ...."
# Start docker service
sudo systemctl daemon-reload
sudo systemctl enable docker.service
sudo systemctl start docker.service
sudo systemctl show --property=Environment docker

log "Adding USER to docker group ...."
# Add default user to the 'docker' group
sudo usermod -aG docker $USER

# We need to log out and back in at this point.
log "Docker has been installed on this host."
log "Host / VM preparation has been completed."
log "Please log out of this session and log back in to continue."
log "After login, please navigate to the ~/z2a script directory and run z2a-ph1b.sh."
