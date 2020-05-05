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
# Makefile 	- targets for Acumos noncore dependencies
#
# 	target:
#		config-helper 		- conconfig-helper (troubleshooting helper pod)
#		kong							- Kong API gateway
# 	mariadb-cds				- MariaDB instance for Common Data Services
# 	nexus							- Sonatype Nexus artifact repository
#

all : config-helper kong mariadb-cds nexus
.PHONY : config-helper kong mariadb-cds nexus

# config-helper
config-helper :
	cp utils.sh.tpl config-helper/utils.sh
config-helper_install : config-helper
	cd config-helper && ./install-config-helper.sh
config-helper_all : config-helper_install

# Kong
kong :
	cp utils.sh.tpl kong/utils.sh
kong_install : kong
	cd kong && ./install-kong.sh
kong_config : kong
	cd kong && ./config-kong.sh
kong_all : kong_install kong_config

# MariaDB/CDS
mariadb-cds :
	cp utils.sh.tpl mariadb-cds/utils.sh
mariadb-cds_install : mariadb-cds
	cd mariadb-cds && ./install-mariadb-cds.sh
mariadb-cds_config : mariadb-cds
	cd mariadb-cds && ./config-mariadb-cds.sh
mariadb-cds_all : mariadb-cds_install mariadb-cds_config

# Nexus
nexus :
	cp utils.sh.tpl nexus/utils.sh
nexus_install : nexus
	cd nexus && ./install-nexus.sh
nexus_config : nexus
	cd nexus && ./config-nexus.sh
nexus_all : nexus_install nexus_config

clean :
	rm  */utils.sh
