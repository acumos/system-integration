#!/bin/bash

#license space.

#########################################################
#General PASS settings(This might turin out to be a seperate .sh file)
# Here we are giving a AWS example - The ACUMOS itself runs on AZURE another PAAS solution that exists in this space
#   INSTALL -- aws.amazon.com/cli
#   VERIFY or SETUP AWS Credentials
#       ~/.aws/credentials on Linux, macOS, or Unix
#       C:\Users\USERNAME \.aws\credentials on Windows

$SCRIPT_PATH="/aws_script.sh"
"$SCRIPT_PATH"

########################################################
#running the docker-compose.
#Defninig the environment variables.

docker-compose up -d


# MariaDb dockerizing and setting up things
docker run --name debian -p 3306:3306 -d debian /bin/sh -c "while true; do ping 8.8.8.8; done"
docker exec -ti debian bash
apt-get -y update
apt-get -y upgrade
apt-get -y install vim

docker run --name mariadbtest -e MYSQL_ROOT_PASSWORD=mypass -d mariadb --log-bin --binlog-format=MIXED
# Nexus dockerizing and setting up things
docker run -d -p 8081:8081 --name nexus sonatype/nexus3

# test it with the following command
#curl -u admin:admin123 http://localhost:8081/service/metrics/ping


#running the bootstrap for onboarding
#runniing the bootstrap for CMS