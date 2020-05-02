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
# Name: z2a-utils.sh - assortment of useful shell utility functions for z2a
#

# Distribution ID function(s)
eval "$(grep ^ID= /etc/os-release)"
rhel() { [[ ${ID} =~ ^(rhel|centos)$ ]]; }
ubuntu() { [[ ${ID} == ubuntu ]]; }

# check for clean namespace in k8s cluster
function check_for_clean_namespace() {
	NAMESPACE=$(gv_read global.namespace)
	OUT=$(kubectl get all -n $NAMESPACE)
	if [[ -n "$OUT" ]] ; then echo "Resources found in $NAMESPACE!" ; exit 1 ; fi
}

# error function for z2a scripts
function fail() {
  caller 0 | (
		set +x
		trap - ERR
		read lineno func filename
		log "${1:-unknown failure at $filename:$lineno}"
		)
	exit 1
}

# read global value from the global_value.yaml file
function gv_read() {
	yq r $ACUMOS_GLOBAL_VALUE $@
}

# Load env environment vars
function load_env() {
	source $Z2A_BASE/user-env.sh
}

# log function for z2a scripts
function log() {
	caller 0 | (
		set +x;
		read l f n;
		logc "$(date -Iseconds) ${n##*/}:$l:($f) $@"
	);
}

# logc function
function logc() {
	echo -e "$@"
	echo -e "$@" >&3
}

# Redirect function for logging (etc.)
function redirect_to() {
	exec 3>&1						# duplicate stdout before redirect
	exec >&$1 2>&1      # redirect stdout/stderr to file
}

# Save environment vars
function save_env() {
	( cat $Z2A_BASE/user-env.sh.tpl ; set | grep ^Z2A_ ) > $Z2A_BASE/user-env.sh
}

# Test to ensure that all Pods are running before proceeding
function wait_for_pods() {
	NAMESPACE=$(gv_read global.namespace)
	i=0 ; wait=$1
	log ".\c"
	while : ; do
		kubectl wait pods --for=condition=Ready --all -n $NAMESPACE --timeout=0 >/dev/null 2>&1 && break
		sleep 1
		(( ++i > wait )) && {
				log "Timed out waiting for pods."
				exit
		}
		logc ".\c"
	done
	logc ""
}
