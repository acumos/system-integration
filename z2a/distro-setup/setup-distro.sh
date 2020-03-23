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
# Name: setup-distro.sh - script to setup distribution dependencies
#
# Dependencies: Centos 7 or Ubuntu

# Determine the end-user actual GID
[[ -z GID ]] && GID=$(id -rg) ; export GID

# check & create /usr/local/bin (binary dependencies installation location)
sudo mkdir -p /usr/local/bin
sudo chown root:root /usr/local/bin
sudo chmod 755 /usr/local/bin

# check create /var/log/acumos-install (central location for installation log files)
sudo mkdir -p /var/log/acumos-install
sudo chown root:$GID /var/log/acumos-install
sudo chmod 664 /var/log/acumos-install

# Add EPEL repo to RHEL/Centos
log "Adding EPEL repo ...."
rhel && {
	rpm -qa | grep -q epel-release ||
		sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	sudo yum -y update
}

log "Adding miscellaneous prerequisites ...."
# RHEL/Centos Distribution misc. requirements
rhel && sudo yum install -y --setopt=skip_missing_names_on_install=False \
	yum-utils device-mapper-persistent-data lvm2 git jq
# Ubuntu Distribution misc. requirements
ubuntu && sudo apt-get update && sudo apt-get install apt-transport-https ca-certificates \
	curl gnupg-agent software-properties-common git jq

log "Setting resources limits ..."
rhel && {
	cat <<EOF | sudo tee -a /etc/sysctl.d/98-inotify.conf
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
EOF
	sudo systemctl --system
}

ubuntu && {
	cat <<EOF | sudo tee -a /etc/sysctl.conf
# Local Modifications
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
EOF
	sudo systemctl -p /etc/sysctl.conf
}

true