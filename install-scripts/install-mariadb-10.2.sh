#!/bin/bash

echo "Installing MariaDB 10.2"

[[ -z $1 ]] && { echo "Usage nstall-mariadb-10.2.sh <MariadiaDBRootPassword> "; exit 1; }

# default version
MARIADB_VERSION='10.2'
MARIADB_PASSWORD=$1

# Import repo key
apt install software-properties-common -y
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
cat << EOF > /etc/apt/sources.list.d/mariadb.list
deb [arch=amd64,i386] http://mirror.jmu.edu/pub/mariadb/repo/10.2/ubuntu xenial main
deb-src http://mirror.jmu.edu/pub/mariadb/repo/10.2/ubuntu xenial main
EOF
# Update
apt update -y

# Install MariaDB without password prompt
debconf-set-selections <<< "maria-db-10.2 mysql-server/root_password password ${MARIADB_PASSWORD}"
debconf-set-selections <<< "maria-db-10.2 mysql-server/root_password_again password ${MARIADB_PASSWORD}"

# Install MariaDB with -qq implies -y --force-yes
apt install -qq mariadb-server -y

# Make MariaDB connectable from outside
sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/my.cnf

sed -i 's/^\!includedir.*//' /etc/mysql/my.cnf
cat << EOF >> /etc/mysql/my.cnf
# Added to use lower case for all tablenames.
[mariadb-10.2]
lower_case_table_names=1
!includedir /etc/mysql/mariadb.conf.d/
EOF

service mysql restart
## Secure mysql installation
mysql_secure_installation <<EOF
${MARIADB_PASSWORD}
n
Y
Y
Y
EOF
