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
# Makefile  - for Acumos plugins and dependencies (2-plugins)
#
#	target:
#	couchdb 		- CouchDB instance for MLWB
#	jupyterhub	- Jupyterhub Notebook facility for MLWB
#	nifi				- NiFi data routing function
#	mlwb				- MLWB installation (top-level)
#

MODULES=couchdb jupyterhub nifi mlwb
all :  check-env $(MODULES)
.PHONY : check-env $(MODULES)
SHELL = /bin/bash
.ONESHELL :

check-env:
ifndef ACUMOS_GLOBAL_VALUE
	$(error ACUMOS_GLOBAL_VALUE is undefined)
endif

$(MODULES) : check-env
	@set -e
	@cp utils.sh.tpl $@/utils.sh
	@cd $@/
	@if [ -x install-$@.sh ] ; then ./install-$@.sh ; fi
	@if [ -x config-$@.sh ] ; then ./config-$@.sh ; fi

clean :
	rm  */utils.sh
