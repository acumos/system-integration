# TODO: add config-helper for standalong operation
# TODO: to the other targets

all : kong mariadb-cds nexus
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
