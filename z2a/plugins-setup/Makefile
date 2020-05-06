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

all: couchdb jupyterhub nifi mlwb
.PHONY: couchdb jupyterhub nifi mlwb

# Couchdb
couchdb :
	cp utils.sh.tpl couchdb/utils.sh
couchdb_install : couchdb
	cd couchdb && ./install-couchdb.sh
# couchdb_config : couchdb
# cd couchdb && ./config-couchdb.sh
couchdb_all : couchdb_install
# couchdb_all : couchdb_install couchdb_config

# JupyterHub
jupyterhub :
	cp utils.sh.tpl jupyterhub/utils.sh
jupyterhub_install : jupyterhub
	cd jupyterhub && ./install-jupyterhub.sh
# jupyterhub_config : jupyterhub
# cd jupyterhub && ./config-jupyterhub.sh
jupyterhub_all : jupyterhub_install
# jupyterhub_all : jupyterhub_install jupyterhub_config

# Nifi
nifi:
	cp utils.sh.tpl nifi/utils.sh
nifi_install : nifi
	cd nifi && ./install-nifi.sh
# nifi_config : nifi
# cd nifi && ./config-nifi.sh
nifi_all : nifi_install
# nifi_all : nifi_install nifi_config

# MLWB
mlwb :
	cp utils.sh.tpl mlwb/utils.sh
mlwb_install : mlwb
	cd mlwb && ./install-mlwb.sh
mlwb_all : mlwb_install

clean :
	rm */utils.sh
