#!/bin/sh
# This shell script can be used as the Docker "CMD" script.
# It waits for the common data service to be reachable,
# then starts the main application for this container.
# It uses a host name managed by the docker-compose tool.

while ! nc -z mlp-cmn-data-svc 8000 ; do
   echo "Waiting for common data service"
   sleep 2
done
java -jar /maven/my-spring-boot-app.*.jar
