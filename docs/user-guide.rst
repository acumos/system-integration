.. ===============LICENSE_START=======================================================
.. Acumos
.. ===================================================================================
.. Copyright (C) 2017-2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
.. ===================================================================================
.. This Acumos documentation file is distributed by AT&T and Tech Mahindra
.. under the Creative Commons Attribution 4.0 International License (the "License");
.. you may not use this file except in compliance with the License.
.. You may obtain a copy of the License at
..  
..      http://creativecommons.org/licenses/by/4.0
..  
.. This file is distributed on an "AS IS" BASIS,
.. WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
.. See the License for the specific language governing permissions and
.. limitations under the License.
.. ===============LICENSE_END=========================================================

=============================
System Integration User Guide
=============================

Acumos API Management with Kong
===============================

According to the `Kong website <https://getkong.org/>`_, Kong is a scalable, open source API Layer/Gateway/Middleware. The Acumos Platform uses Kong as a reverse proxy server. SSL certificates are installed on the Kong server so each containerized app doesn't have to install its own certs. Kong is highly configurable. Browse the `Kong documentation <https://getkong.org/docs/>`_ for a detailed description and user guides.

Kong API helps in reducing the rewriting of the same piece of code again and again for SSL certificates configuration in order to make the API secure. Now we don't need to do any coding/configuration work in API anymore.

Backend Architecture

.. image:: images/AcumosKongAPI.jpg	

*Note: All the configuration data sent through the Admin API is stored in Kong's data store. Kong is capable of supporting both Postgres and Cassandra as storage backend. We have chosen Postgres. 


Kong API component versions
---------------------------

- postgres:9.4
- kong:0.11.0
	 
Acumos Kong API setup
---------------------

Kong API completely containerized solution is automated with docker compose. It installed with its own docker-compose file.

In dockers-compose definition, there are three services: 

- kong-database
- kong-migration
- kong

Kong uses an external datastore to store its configuration such as registered APIs, Consumers and Plugins. 
The entire configuration data is stored in Kong's data store. The kong-migration service is used to create the objects in the kong-database. This bootstrap functionality is not provided by kong service, so kong-migration service run once inside the container.

By default Kong listens on the following ports:

	:8000 on which Kong listens for incoming HTTP traffic from your clients, and forwards it to your upstream services.
	
	:8443 on which Kong listens for incoming HTTPS traffic. This port has a similar behavior as the :8000 port, except that it expects HTTPS traffic only. This port can be disabled via the configuration file.
	
	:8001 on which the Admin API used to configure Kong listens.
	
	:8444 on which the Admin API listens for HTTPS traffic.	  
	
Acumos Kong is running on port 

	:7000 on which Acumos Kong listens for incoming HTTP traffic from your clients, and forwards it to your upstream services.
	
	:443 on which Acumos Kong listens for incoming HTTPS traffic. This port has a similar behavior as the :7000 port, except that it expects HTTPS traffic only. This port can be disabled via the configuration file.
	
	:7001 on which the Admin API used to configure Acumos Kong listens.
	
	:7004 on which the Admin API listens for HTTPS traffic.	  
	
	
*Note: Acumos Kong API docker-compose.yml and shell script can be run before or after the main docker-compose. Ensure before access the service URL via acumos Kong API all the services which we are going to access should be up and running.
	
Prerequisites
-------------
`Docker <https://docs.docker.com/>`_ and `Docker Compose <https://docs.docker.com/compose/install/>`_ installed


Steps
-----

1. Clone the system-integration repository 

.. code-block:: bash
   
   $ git clone https://gerrit.acumos.org/r/system-integration
  
2. Builds, (re)creates, starts, and attaches to containers for kong, postgres.

.. code-block:: bash
	
   $ ./docker-compose-kong.sh up -d  	
				
		 
3. To stop the running containers without removing them 

.. code-block:: bash	

   $ ./docker-compose-kong.sh stop   
   
  

Steps to create self signed in certificate
------------------------------------------
1. Create the private server key

.. code-block:: bash

      openssl genrsa -des3 -out server.key 2048

2. Now we create a certificate signing request

.. code-block:: bash

      openssl req -new -key server.key -out server.csr -sha256

3. Remove the passphrase

.. code-block:: bash

      cp server.key server.key.org

.. code-block:: bash

      openssl rsa -in server.key.org -out server.key

4. Signing the SSL certificate

.. code-block:: bash

      openssl x509 -req -in server.csr -signkey server.key -out server.crt -sha256
	  

	  
Acumos API configuration
------------------------

Please update the configuration settings in "secure-acumos-api.sh" script to match your environment:

1.  Copy your host certificate and key under acumos-kong-api "certs" directory

2.  Change the values of placeholders below before running the script

.. code-block:: bash

   
      export ACUMOS_KONG_CERTIFICATE_PATH=./certs
	  
      export ACUMOS_CRT=localhost.csr
	  
      export ACUMOS_KEY=localhost.key
	  
      export ACUMOS_HOST_NAME=<your hostname>
	  
      export ACUMOS_HOME_PAGE_PORT=8085
	  
      export ACUMOS_CCDS_PORT=8003
	  
      export ACUMOS_ONBOARDING_PORT=8090
	  

	  
Run the "secure-acumos-api.sh" script, Please ensure that Acumos Kong API container is up.

.. code-block:: bash

     ./secure-acumos-api.sh         
   
   
 Expose new service:
--------------------------

Use the Admin API port 7001 to configure Kong. Acumos standard sample to expose the service is present in shell script:

.. code-block:: bash

     ./secure-acumos-api.sh         
   
   
For more details visit `Kong documentation <https://getkong.org/docs/0.5.x/admin-api/>`_, 
     