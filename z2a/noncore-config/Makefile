all : kong mariadb-cds nexus
.PHONY : kong mariadb-cds nexus

# Kong
kong :
	cp utils.sh.tpl kong/utils.sh
kong_install : kong
	cd kong && ./install-kong.sh
# kong_config : kong
#       cd kong && ./config-kong.sh
kong_all : kong_install 
	
# MariaDB/CDS
mariadb-cds :
	cp utils.sh.tpl mariadb-cds/utils.sh
mariadb-cds_install : mariadb-cds
	cd mariadb-cds && ./setup-mariadb-cds.sh
# mariadb-cds_config : mariadb-cds
#       cd mariadb-cds && ./config-mariadb-cds.sh
mariadb-cds_all : mariadb_cds_install 

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
