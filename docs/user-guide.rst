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
	 
Prerequisites
-------------
`Docker <https://docs.docker.com/>`_ and `Docker Compose <https://docs.docker.com/compose/install/>`_ installed


Steps
-----

1. Clone the system-integration repository 

.. code-block:: bash
   
   $ git clone https://gerrit.acumos.org/r/system-integration
   

2. You need to build the docker-compose file if you are using it for the first time or if you have changed any Dockerfile or the contents of its build directory.

.. code-block:: bash
	
   $ docker-compose build  
   
	
3. Builds, (re)creates, starts, and attaches to containers for kong, postgres.

.. code-block:: bash
	
   $ docker-compose up -d  	
				
		 
4. To stop the running containers without removing them 

.. code-block:: bash	

   $ docker-compose stop   
   
   
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
   
   
   