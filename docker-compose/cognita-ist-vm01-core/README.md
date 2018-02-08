# Docker-Compose for Host cognita-ist-vm01-core

This directory has a CI/CD script for managing docker containers on host cognita-ist-vm01-core.
The script has all required configuration for the database, common data service, and more.

Deploy all the containers like this:

    docker-compose up

Note that this script does NOT have credentials for the docker registry.  You must login
to the registry like this:

    docker login -u username -p password cognita-nexus01.eastus.cloudapp.azure.com:8002
