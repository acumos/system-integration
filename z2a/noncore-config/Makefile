all : kong mariadb nexus
.PHONY : kong mariadb nexus

kong :
	cp utils.sh.tpl kong/utils.sh

mariadb :
	cp utils.sh.tpl mariadb/utils.sh

nexus :
	cp utils.sh.tpl nexus/utils.sh

install_mariadb : mariadb
	cd mariadb && ./setup-mariadb.sh

clean :
	rm  */utils.sh

