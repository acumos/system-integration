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
# Name: utils.sh.tpl - assortment of useful shell utility functions as a template
#
#

# fail function
function fail() {
	eval "echo FAIL: $@"
	exit 1
}

# read global value from the global_value.yaml file
function gv_read() {
	yq r $ACUMOS_GLOBAL_VALUE $@
}

# log function
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
	exec >&$1 2>&1 			# redirect stdout/stderr to file
}

# Test to ensure that all Pods are running before proceeding
# TODO: add logic to wait for specific pods
function wait_for_pods() {
	NAMESPACE=$(gv_read global.namespace)
	i=0 ; wait=$1
	log ".\c"
	while : ; do
		# PODS="$(kubectl get pods -n $NAMESPACE --field-selector 'status.phase!=Running','status.phase!=Succeeded' -A 2>/dev/null)"
		PODS="$(kubectl get pods -n $NAMESPACE -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' 2>/dev/null | grep -v true)"
		if [[ -z $PODS ]]; then break ; fi
		sleep 1
		(( ++i > wait )) && {
				log "Timed out waiting for pods."
				exit
		}
		logc ".\c"
	done
	logc ""
}

# Kubernetes service lookup function
function svc_lookup() {
	helm get manifest $1 -n $2 | yq r -d'*' -j - | grep '"kind":"Service"' | jq -r .metadata.name
}

# INIT
[[ -n $ACUMOS_GLOBAL_VALUE ]] || fail "ACUMOS_GLOBAL_VALUE not defined!"
[[ -f $ACUMOS_GLOBAL_VALUE ]] || fail "$ACUMOS_GLOBAL_VALUE not found!"