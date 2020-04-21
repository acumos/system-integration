all : kong mariadb-cds nexus
.PHONY : kong mariadb-cds nexus

kong :
	cp utils.sh.tpl kong/utils.sh

# MariaDB/CDS
mariadb-cds :
	cp utils.sh.tpl mariadb-cds/utils.sh
install_mariadb-cds : mariadb-cds
	cd mariadb-cds && ./setup-mariadb-cds.sh

# Nexus
nexus :
	cp utils.sh.tpl nexus/utils.sh
install_nexus : nexus
	cd nexus && ./install-nexus.sh && ./config-nexus.sh

clean :
	rm  */utils.sh

