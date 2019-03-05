.. ===============LICENSE_START=======================================================
.. Acumos CC-BY-4.0
.. ===================================================================================
.. Copyright (C) 2017-2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
.. ===================================================================================
.. This Acumos documentation file is distributed by AT&T and Tech Mahindra
.. under the Creative Commons Attribution 4.0 International License (the "License");
.. you may not use this file except in compliance with the License.
.. You may obtain a copy of the License at
..
.. http://creativecommons.org/licenses/by/4.0
..
.. This file is distributed on an "AS IS" BASIS,
.. See the License for the specific language governing permissions and
.. limitations under the License.
.. ===============LICENSE_END=========================================================

Introduction
============

This user guide describes how to deploy Acumos platforms using the
"One Click deploy" tools designed for developers or those who want a simple and
automated way to deploy an Acumos platform. Currently deployment supports an
all-in-one (AIO) target.

What is an AIO deploy?
----------------------

By default, the AIO deploy tools build an all-in-one instance of Acumos, with
all Acumos data and components running under docker or kubernetes (k8s) on a
single virtual machine or physical host machine.

For k8s based deployments, both generic (standard k8s project tools) and
OpenShift (RedHat's k8s distribution) are supported.

Options also allow the user to deploy the platform on a cluster of nodes, to
deploy a subset of the components, and to use some components that have
previously deployed somewhere.

For the Impatient (TL;DR)
-------------------------

NOTICE:

* this process will remove/install software on your host, and configure
  it e.g. firewall and security rules. Only execute this process if you understand
  the implications or are executing the process in a VM/host that you can easily
  re-create.
* by default, the Acumos platform is deployed with service exposure options
  typical for development environments. Production environments and especially
  public environments will need additional planning and restrictions on exposed
  services, that otherwise could expose your host to security risks. FOR TEST
  PURPOSES ONLY; USE AT YOUR OWN RISK.

Deploying as a Privileged (sudo) User
.....................................

This process is for a user that wants to execute all steps in the deployment
process using their host account. To deploy the Acumos platform with the default
options, as a user on a linux host with at least 16GB RAM and admin (sudo)
permission, follow the process below.

* clone the system-integration repo

  .. code-block:: bash

    $ git clone https://gerrit.acumos.org/r/system-integration
  ..

* using bash, check if the user is part of the docker group, and add if not

  .. code-block:: bash

    $ if [[ "$(id -nG "$USER" | grep docker)" == "" ]]; then sudo usermod -G docker $USER; fi
  ..

  * if you see "usermod: group 'docker' does not exist", install docker (e.g.
    using setup-docker.sh in the system-integration/tools folder) and run the
    command above again. Once you do not see the message above, logout and re-login.

* execute the following command to install/configure prerequisites, including
  k8s, MariaDB, and the ELK stack, using your user account, and hostname as the
  domain name you will use to access the deployed platform.

  .. code-block:: bash

    $ bash system-integration/AIO/acumos_k8s_prep.sh $USER $HOSTNAME
  ..

* When you see "Prerequisites setup is complete." as the result of the
  command above, execute the following commands to complete platform setup

  .. code-block:: bash

    $ cd system-integration/AIO
    $ bash acumos_k8s_deploy.sh
  ..

* when that command completes successfully, you should see a set of URLs to
  access the various platform services. You can also view the file "acumos.url"
  which will be in the system-integration/AIO folder (example below)

  .. code-block:: bash

    $ cat system-integration/AIO/acumos.url
    Portal: https://acumos.example.com:30443
    Common Data Service: https://acumos.example.com:30443/ccds/swagger-ui.html
    Kibana: http://acumos.example.com:30561/app/kibana
    Nexus: http://acumos.example.com:30881
    Mariadb Admin: http://acumos.example.com:30380
    Kong Admin: http://acumos.example.com:30081

  ..

* By default, the platform is not configured to require email confirmation of
  new accounts, so you can create a new account directly on the Portal home. To
  create an account with the Admin role (needed for various platform admin
  functions), use the create-user.sh script in the system-integration/AIO folder


Preparation by Host Admin with Platform Deployment by Normal (non-sudo) User
............................................................................

This process is for a host Admin (sudo user) to prepare the host for a normal
(non-sudo) user that will complete the platform deployment, under their account.

* Admin clones the system-integration repo

  .. code-block:: bash

    $ git clone https://gerrit.acumos.org/r/system-integration
  ..

* Admin ensures the user is part of the docker group
* Admin executes the following command to install/configure prerequisites,
  including k8s, MariaDB, and the ELK stack, using their account. <user> in this
  case is the username of the normal user that will complete the deployment.

  .. code-block:: bash

    $ bash system-integration/AIO/acumos_k8s_prep.sh <user> $HOSTNAME
  ..

* When prerequisites setup is complete, the Admin copies the resulting
  environment files and system-integration clone to the user account, e.g.

  .. code-block:: bash

    sudo cp -r acumos /home/<user>/.
    sudo chown <user>:<user> /home/<user>/acumos
    sudo cp -r system-integration /home/<user>/.
    sudo chown <user>:<user> /home/<user>/system-integration

* The user executes the following commands to complete platform setup

  .. code-block:: bash

    $ cd system-integration/AIO
    $ bash acumos_k8s_deploy.sh
  ..



What's included in the AIO tools
--------------------------------

In system-integration repo folder AIO:

* acumos_k8s_prep.sh: Script to be used by a host admin (a user with privilege
  to install applications and configure the host) to prepare a host for a normal
  user to later deploy/manage the Acumos platform there, under a generic k8s
  cluster.
* setup_prereqs.sh: Prerequisite setup script for AIO deployment of the
  Acumos platform. Intended to support users who do not have sudo permission, to
  have a host admin (sudo user) run this script in advance for them. Used by
  acumos_k8s_prep.sh and other target environment support scripts (WIP).
* acumos_k8s_deploy.sh: Script used by a normal to deploy/manage the Acumos
  platform under generic k8s, once the host has been prepared by an admin using
  acumos_k8s_prep.sh.
* oneclick_deploy.sh: the main script that kicks off the deployment, to setup
  an AIO instance of Acumos under a docker or kubernetes environment. Used by
  acumos_k8s_deploy.sh, or by users to initiate Acumos platform deployment.
* acumos-env.sh: environment setup script that is customized as new
  environment parameters get generated (e.g. passwords). Used by various
  scripts in this toolset, to set shell environment variables that they need.
* utils.sh: utility script containing functions used by many of these scripts.
* setup-keystore.sh: script that enables use of pre-configured CA and server
  certificates for an Acumos platform, or creation of new self-signed
  certificates.
* clean.sh: script you can run as “bash clean.sh” to remove the Acumos install,
  to try it again etc.
* docker-compose.sh: Script called by the other scripts as needed, to take
  actions on the set of Acumos docker services. Used by oneclick_deploy.sh and
  clean.sh for docker-based deployments. You can also call this directly e.g.
  to tail the service container logs. See the script for details.
* peer-test.sh: Automated deployment of two AIO platforms, with federation and
  demo model onboarding. Used to test federation use cases.
* create-peer.sh: Automated setup of a peer relationship between two Acumos
  AIO deployments. Used by peer-test.sh.
* create-user.sh: Automated user provisioning and role assignment. Used by
  peer-test.sh to create users for model onboarding, and portal admins for
  testing federation actions on the Acumos platform.
* create_subscription.sh: script to create a subscription for all models
  published by a federated Acumos platform.
* bootstrap-models.sh: Model package onboarding via curl. Optionally called by
  peer-test.sh.

In folder AIO/docker/acumos:

* docker-compose yaml files and deployment script for Acumos core components.

In folder AIO/kubernetes:

* under deployment, kubernetes deployment templates for all system components
* under service, kubernetes service templates for all system components

In folder AIO/beats:

* deployment scripts and templates for the Filebeat and Metricbeat services
  as ELK stack components deployed along with the Acumos platform.

In folder AIO/certs:

* setup-certs.sh: script to create self-signed CA and server certs.
* This folder is also used to stage user-provided certs to be used in Acumos
  platform deployment.

In folder AIO/docker-engine:

* scripts and templates to deploy docker-in-docker as the docker-engine service
  for k8s-based Acumos platforms

In folder AIO/docker-proxy:

* scripts and templates for deployment of the docker-proxy core component of the
  Acumos platform

In AIO/elk-stack:

* scripts and templates to deploy the ELK stack core components under docker

In AIO/kong:

* scripts and templates to deploy the Kong service as an ingress controller for
  the Acumos platform

In AIO/mariadb:

* scripts and templates to deploy the MariaDB under docker, as the Acumos
  platform database backend service

In AIO/nexus:

* scripts and templates to deploy the Nexus service for the Acumos platform

In charts:

* scripts and templates to deploy the following components for k8s-based
  deployments, using Helm as deployment tool

  * elk-stack: ELK stack core components
  * jupyterhub: the JupterHub/JupyterLab services for notebook-based model
    development
  * mariadb: MariaDB service
  * nifi: the NiFi service for data pipeline development
  * zeppelin: the Zeppelin service for notebook-based model development

In tools:

  * setup_helm.sh: script to setup Helm as a service deployment tool
  * setup_k8s.sh: script to setup a generic k8s cluster
  * setup_mariadb_client.sh: script to setup the MariaDB client as used by other
    scripts to configure the Acumos database
  * setup_openshift_client.sh: script to setup the OpenShift client (oc) tool
    used by other scripts and users to manage and interact with OpenShift based
    platform deployments.
  * setup_prometheus.sh: script to setup the Prometheus monitoring service, with
    Grafana as a data visualization tool, for monitoring the Acumos platform's
    resources at the k8s level. Also deploys Grafana dashboards in the dashboards
    folder.
  * setup-docker.sh: script to setup the docker version used for docker-based
    platform deployment and interaction.
  * setup-kubectl.sh: script to setup the kubectl tool used by other scripts and
    the user to manage and interact with generic k8s based deployments.
  * setup-pv.sh: script to setup host-based persistent volumes for use with
    docker and k8s-based platform deployments.

Release Scope
=============

Current Release (Boreas)
------------------------

The Boreas release includes these capabilities that have been implemented/tested:

* single-node (AIO) deployment of the Acumos platform under docker or kubernetes
* deployment with a new Acumos database, or redepoyment with a current database
  and components compatible with that database version
* Component services under docker/kubernetes as named below (deployed as
  distinct container-based services), or installed directly on the AIO host:

  * core components of the Acumos platform

    * Portal Marketplace: portal-fe-service, portal-be-service
    * Hippo CMS: cms-service
    * Solution Onboarding: onboarding-service
    * Design Studio Composition Engine: dsce-service
    * Federation Gateway: federation-service
    * Azure Client: azure-client-service
    * Common Data Service: cds-service
    * Filebeat: filebeat-service

  * external/dependency components

    * docker engine/API: docker-service (under kubernetes), or docker running on
      the AIO host for docker-based deployment
    * MariaDB: mariadb running on the AIO host
    * Kong proxy: kong-service
    * Nexus: nexus-service

The Athena release will include these capabilites in development:

  * Deployment in a multi-node configuration under kubernetes
  * Deployment of or integration with a backend Shared-Data-Service (SDS) for
    Persistent Volume Claims (PVC) under kubernetes
  * Deployment with upgrade migration of an existing Acumos database
  * Deployment with integration to pre-existing external components: MariaDB,
    Nexus, proxy, ELK stack
  * Additional platform core components

    * Metricbeat
    * OpenStack Client
    * Microservice Generation
    * Security Verification
    * Kubernetes Client
    * Docker Proxy

  * Additional external/dependency components

    * ELK stack

Future Releases
---------------
Future releases may include these new features:

* Deployent in AIO or multi-node configuration on public clouds

Step-by-Step Guide
==================

Prerequisites
-------------

This guide assumes:

* you are deploying either:

  * a single AIO instance of the Acumos platform, via "oneclick_deploy.sh"
  * two AIO instances of the Acumos platform as peers, via "peer-test.sh"

* each Acumos host is an Ubuntu 16.04.x desktop/server, with at least 16GB of
  RAM (recommended). The Acumos platform as deployed by this script on bare
  metal consumes currently about 6GB of RAM, so may be deployable in hosts with
  less than 16GB RAM.
* you are deploying the AIO platform(s) to host(s):

 * that have a hostname resolvable by DNS or through the hosts file of whatever
   machine you use to interact the Acumos web portal (referred to here as the
   "portal") and platform APIs such as onboarding and federation.
 * that have access to the internet, either directly or through a proxy
 * to which you have full access to the target host, i.e. all ports are accessible
 * to which you have shell access (for a single AIO instance) or key-based SSH
   access (for peer-test deployment)

* Note the target host(s) can be another physical host, or a VM running on your
  workstation

Install Process
---------------

The notes below provide an overview of the installation process.
See `Verified Features`_ below for a summary of what's
been verified to work in the test environments where this has been
used.

* Open a shell session (bash recommended) on the host on which (for single AIO
  deployment) or from which (for peer-test deployment) you want to install
  Acumos, and clone the system-integration repo:

  .. code-block:: bash

    git clone https://gerrit.acumos.org/r/system-integration
  ..

* In the system-integration/AIO folder

  * Customize the acumos-env.sh script per your environment's needs, e.g.
    specify any proxy settings required, or select specific component ports
    other than the default, etc

    * If you are redeploying/restarting the platform, you can preserve the
      current database and any models you have onboarded, by setting the
      ACUMOS_CDS_PREVIOUS_VERSION environment variable in acumos-env.sh to the
      same value as the ACUMOS_CDS_VERSION variable, as shown below:

      .. code-block:: bash

        export ACUMOS_CDS_PREVIOUS_VERSION=1.16
        export ACUMOS_CDS_VERSION=1.16
      ..

    * The script will preserve an existing database and all the related
      credentials (MariaDB, Nexus, CDS, ...) during the deployment, if the
      ACUMOS_CDS_PREVIOUS_VERSION variable is set. This will also be supported
      for database upgrade in a coming version (the capability is developed, but
      not fully tested).

  * If you are deploying a single AIO instance, run the following command,
    selecting docker or kubernetes as the target environment. Further
    instructions for running the script are included at the top of the script.

    .. code-block:: bash

      bash oneclick_deploy.sh <docker|k8s>
    ..

  * If you are deploying two Acumos AIO instances as peers, run the following
    command (NOTE: "under the hood", this uses onclick_deploy.sh):

    .. code-block:: bash

      bash peer-test.sh <host1> <user1> <under1> <host2> <user2> <under2> [models]
    ..

  * For the above commands specify:

    * "docker" to install all components other than mariadb and the
      docker-engine under docker-ce
    * "k8s" to install all components other than mariadb under kubernetes
    * "\<host1\>"/"\<user1\>" as hostname and user account to install under for
      the first peer, and "\<host2\>"/"\<user2\>" similarly for the second peer
    * optionally, for "[models]" specify a folder with Acumos models to be
      onboarded under a "test" user account (an admin user, automatically
      created by the peer-test.sh script)

 * The deployment will take 5-20 minutes depending upon whether you have run
   this command before and thus docker has already downloaded the Acumos docker
   images. That will speed up subsequent re-deploys.

* When deployment is complete, you should see a message similar to this, stating
  the URL for the Portal:

    .. image:: images/oneclick-complete.png
       :width: 100 %

* To enable all Portal content, you will need to complete one manual setup
  action for the Hippo CMS. Note this action is not required to use the Portal,
  just to ensure that all Portal-displayed info is presented correctly. Follow
  these steps on each AIO host (replacing "\<hostname\>" with the applicable
  name for the host):

 * Login to the Hippo CMS console as "admin/admin", at
   http://<hostname>:<ACUMOS_CMS_PORT>/cms/console, where ACUMOS_CMS_PORT is per
   acumos-env.sh; for the default, the address is acumos:30980/cms/console

    .. image:: images/acumos-cms-login.png
       :width: 100 %

 * On the host where you installed the AIO Platform, login to the account you
   used when installing, and copy the contents of file aio-cms-host.yaml

 * On the CMS UI at the left, click the + at ``hst:hst`` and then right-click
   ``hst:hosts``, and select "Yaml Import". In the resulting dialog, paste the
   copied contents of file aio-cms-host.yaml

    .. image:: images/acumos-cms-yaml-import.png
       :width: 100 %

 * When the dialog closes, you should be able to see a new node "AIO" under
   ``hst:hosts``. You can now your changes by pressing the
   ``Write changes to repository`` button in the upper right.

    .. image:: images/acumos-cms-write-changes.png
       :width: 100 %

* Update your local workstation's hosts file so the portal domain name
  "<hostname>" will resolve on your workstation. Add a line: <ip address of
  your AIO host> <hostname>. Note: on Ubuntu, the hosts file is at
  ``/etc/hosts``. The example below is from an Ubuntu laptop with the
  AIO instance running in a Virtual Box environment.

    .. image:: images/hosts-file.png
       :width: 100 %

* Create an admin user: the oneclick_deploy.sh script **does not** create a
  default user. However, you can use the ``create-user.sh`` script to create
  an "Admin" user for the platform. The ``create-user.sh`` script is located
  in the same directory as the ``oneclick-deploy.sh`` script. Usage
  instructions are included at the top of the ``create-user.sh`` script.
  Below is an example of how to create an admin user:

    .. code-block:: bash

        $ bash create-user.sh admin Admin123 Admin Admin admin@admin.net Admin
        ...(lots of output)
        $ User creation is complete


* You should now be able to browse to the Acumos platform by going to https://<hostname>:30443, and

 * register new user accounts, etc
 * if you deployed a peer-test set of Acumos portals, log into the "test" user
   account with password per peer-test.sh (see line with "bash create-user.sh")
 * If you get a browser warning, just accept the self-signed cert and proceed.

Updating Configuration and Components
-------------------------------------

As described in `Install Process`_ and `Stopping, Restarting, and Reinstalling`_,
you can redeploy the whole platform without losing current data (e.g. users and
models), by changing the values in acumos-env.sh (as updated by an earlier
install process) as needed, leaving the rest as-is, and re-executing the
deployment command you used for the previous deployment.

However, this process is not guaranteed to be fail-proof, and if you are
concerned about the ability to recover database items that may be lost, it is
recommended that you first backup the databases or export data from them. Some
tools have been developed for this, e.g.

* `dump-model.sh <https://github.com/acumos/test-models/blob/master/tools/dump-model.sh>`_:
  this tool is intended to enable export of all artifacts related to one or
  more models by solution/revision

The following types of redeployment are regularly tested as part of the AIO
toolset development:

* updating the configuration

  * values in acumos-env.sh, or values in the component templates etc, can be
    modified and re-applied by redeploying the components. Note however that
    some values may not work with previous data, as the related components
    are not redeployed/reconfigured. For example, the following values should
    not be changed without a clean redeploy:

    * domain name of the Acumos platform

      * ACUMOS_DOMAIN

    * CDS settings

      * ACUMOS_CDS_PASSWORD

    * Nexus settings

      * ACUMOS_NEXUS_ADMIN_USERNAME
      * ACUMOS_NEXUS_ADMIN_PASSWORD
      * ACUMOS_RO_USER
      * ACUMOS_RO_USER_PASSWORD
      * ACUMOS_RW_USER
      * ACUMOS_RW_USER_PASSWORD

    * server certificate credentials

      * ACUMOS_KEYPASS

* upgrading a specific component or set of components

  * components can be upgraded, e.g. for testing or to move to a new
    `release assembly <https://wiki.acumos.org/display/REL/Weekly+Builds>`_.
    However, ensure that you have addressed any component template changes,
    as described by the release notes for the new component versions.

* upgrading the CDS database version

  * CDS version changes sometimes result in a new version of the CDS database
    schema. Version upgrades are supported by the AIO toolset, given that there
    is an available mysql upgrade script in the common-dataservice repo. Scripts
    are provided for an incremental update only; see the
    `CDS github mirror <https://github.com/acumos/common-dataservice/tree/master/cmn-data-svc-server/db-scripts>`_
    for examples of the available scripts.

Stopping, Restarting, and Reinstalling
--------------------------------------

If you deployed under docker, you can stop all the Acumos components (e.g. to
suspend/shutdown your host) without losing their databases via the command:

.. code-block:: bash

  sudo bash docker-compose.sh stop

Restart the services later using the following command (note it may take a few
minutes for all to be active):

.. code-block:: bash

  sudo bash docker-compose.sh restart

If you deployed under kubernetes, you can also restart the whole platform, by
the following command, as long as the generated values in acumos-env.sh (e.g.
passwords for MariaDB, CDS, Nexus, ...) have not been changed:

.. code-block:: bash

  bash oneclick_deploy.sh k8s

If you deployed under kubernetes, you can also restart a specific component by
the name of the deployment. As in the example below, you can use the kubectl
command to get the deployment names. Note that:

  * the deployment templates as updated by oneclick-deploy.sh (substituting
    variables as needed) are in the subfolder deploy/kubernetes/deployment
  * the elasticsearch, logstash, and kibana deployments are all defined in
    file elk-deployment.yaml, so when recreating any of these, refer to that
    file in the ``kubectl create -f`` command

.. code-block:: bash

  $ kubectl get deployments -n acumos
  NAME                DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
  azure-client        1         1         1            1           5d
  cds                 1         1         1            1           5d
  cms                 1         1         1            1           5d
  docker              1         1         1            1           5d
  dsce                1         1         1            1           5d
  elasticsearch       1         1         1            1           5d
  federation          1         1         1            1           5d
  filebeat            1         1         1            1           5d
  kibana              1         1         1            1           5d
  kong                1         1         1            1           5d
  kubernetes-client   1         1         1            1           3m
  logstash            1         1         1            1           5d
  metricbeat          1         1         1            1           5d
  msg                 1         1         1            1           5d
  nexus               1         1         1            1           5d
  onboarding          1         1         1            1           5d
  portal-be           1         1         1            1           5d
  portal-fe           1         1         1            1           5d

  $ kubectl delete deployment -n acumos kubernetes-client
  deployment.extensions "kubernetes-client" deleted
  $ kubectl create -f deploy/kubernetes/deployment/kubernetes-client-deployment.yaml
  deployment.apps "kubernetes-client" created

You can clean the installation (including all data) via:

.. code-block:: bash

  bash clean.sh

Verified Features
-----------------
new user registration

The following Acumos platform workflows and related features have been verified as
working so far. This list will be updated as more workflows are verified.

The following features are verified as part of the process of deployment or
post-deployment through the referenced test scripts:

* high-level deployment scenarios under which specific tests are executed

  * Deploy with all-new components

    * leave ACUMOS_CDS_PREVIOUS_VERSION as the default (blank) and execute deployment

  * Redeploy with pre-existing mariadb, nexus, etc

    * set ACUMOS_CDS_PREVIOUS_VERSION to the same value as ACUMOS_CDS_VERSION
      in acumos-env.sh and execute deployment

  * Redeploy with upgraded database

    * in acumos-env.sh, set ACUMOS_CDS_PREVIOUS_VERSION to the value of
      ACUMOS_CDS_VERSION as used in the last deployment, and increment
      ACUMOS_CDS_VERSION to the next version of the CDS, and execute deployment

* new user registration: `create-user.sh <https://github.com/acumos/system-integration/blob/master/AIO/create-user.sh>`_

  * Create user, via Portal API /api/users/register
  * Finding role by name, via CDS API /ccds/role
  * Create role by name, via CDS API /ccds/role
  * Assign role to user, via /ccds/user
  * Get role for user, via CDS API /ccds/user/$userId/role/$roleId
  * Get user account details, via CDS API /ccds/user/$userId

* 'self' peer creation: `oneclick-deploy.sh <https://github.com/acumos/system-integration/blob/master/AIO/oneclick-deploy.sh>`_

  * Create 'self' peer, via CDS API /ccds/peer

* remote peer creation: `create-peer.sh <https://github.com/acumos/system-integration/blob/master/AIO/create-peer.sh>`_

  * Get userId of user, via CDS API /ccds/user
  * Create peer, via CDS API /ccds/peer
  * Apply new truststore entry by restarting the Federation service
  * Subscribe to all solution types at peer, via CDS API /ccds/peer/sub
  * get list of solutions, via Federation API /solutions

* model onboarding via command line: `bootstrap-models.sh <https://github.com/acumos/system-integration/blob/master/AIO/bootstrap-models.sh>`_
  and `onboard-model.sh <https://github.com/acumos/test-models/blob/master/tools/onboard-model.sh>`_

  * User authentication and JWT token retrieval, via Onboarding API
    /onboarding-app/v2/auth
  * Model onboarding, via Onboarding API /onboarding-app/v2/models
  * Onboarding of normal models and "Datasource" type models

The following manual tests are regularly verified as part of AIO testing:

* user login
* user signup
* model onboarding via web
* model sharing with another user
* model publication to company marketplace
* model publication to public marketplace
* federated peer relationship creation via portal
* federated subscription to public marketplace models
* verification of subscribed model presence in public marketplace
* creation of composite solution
* addition of probe to composite solution
* setting Datasource model Category "Data Sources" and Toolkit "Data Broker"
* creation of composite solution with Datasource
* model deployment in private kubernetes ("deploy to local")

  * simple model
  * composite model
  * composite model with Probe
  * composite model with Probe and Data Broker

Notes on Verified Features
--------------------------

User registration and login
...........................

A test script to automate user account creation and role assignment has been
included in this repo. See
`create-user.sh <https://github.com/acumos/system-integration/blob/master/AIO/create-user.sh>`_
for info and usage. For an example of
this script in use, see `Federation`_.

Model onboarding via command line
.................................

Currently this is verified by posting a model package to the onboarding API,
as toolkit clients will do when installed. Two scripts are used for this:

* `bootstrap-models.sh <https://github.com/acumos/system-integration/blob/master/AIO/bootstrap-models.sh>`_

  * onboard all models in a folder; models are in subfolders and include the
    three essential artifacts, as generated by an onboarding client, or
    downloaded earlier from an Acumos portal

    * model.zip
    * metadata.json
    * a .proto file, either model.proto (normal models) or default.proto
      (Datasource type models)

* `onboard-model.sh <https://github.com/acumos/test-models/blob/master/tools/onboard-model.sh>`_

  * onboard a specific model (a folder with the files as describe above)

Federation
..........

oneclick_deploy.sh will automatically create a "self" peer as required by the
federation-gateway.

If you want to deploy two Acumos AIO instances to test federation, see these
scripts for info and usage:

* peer-test.sh: installs and peers two Acumos AIO instances, on two hosts, and
  optionally uploads model packages via curl.

* create-peer.sh: used by peer-test.sh. You can call this script directly to
  add a peer to an existing Acumos platform.

You can also manually create a federated peer:

* If you have not created an admin user, run create-user.sh as above to create
  one.
* Login to the portal as the admin user
* Under the "SITE ADMIN" page, select "Add Peer", enter these values, and select
  "Done":

 * Peer Name: FQDN of the peer
 * Server FQDN: DNS-resolvable FQDN of the peer
 * API Url: http://\<FQDN of the peer\>:\<federation-gateway port from
   acumos-env.sh\>
 * Peer Admin Email: any valid email address

* Verify that the peer relationship was setup via executing these commands on
  the AIO host

 * source acumos-env.sh
 * curl -vk --cert certs/acumos.crt --key certs/acumos.key <API Url as above>

* You should see details of the HTTPS connection followed by

  .. code-block:: bash

    {"error":null,"message":"available public solution for given filter",
    "content":[...]}
  ..

* This indicates that the request for "solutions" was accepted. "..." will
  either be "" (no solutions) or a JSON blob with the solution details.

Features Pending Verification
-----------------------------

* model onboarding via web
* model private sharing with user
* model launch
* design studio

Logs Location
=============
Logs are easily accessible on the AIO host in the /var/acumos directory.

  .. code-block:: bash

    $ ls /var/acumos/logs
    $ acumos-azure-client  ccds  ds-compositionengine  federation-gateway  kubernetes-client  microservice-generation  on-boarding  portal-be  portal-fe

    $ ls /var/acumos/logs/portal-be
    $ access.log  audit.log  debug.log  error.log

These host folders are mapped to persistent volumes exposed to the components.


Additional Notes
================

The scripts etc in this repo install Acumos with a default set of values for
key environment variables. See acumos-env.sh for these defaults. You should be
able to modify any explicit value (not variables) defined there, but some
additional steps may be needed for the installed platform to work with the
updated values. For example:

* To use a non-default domain name for the acumos AIO server
  (default: acumos), change ACUMOS_DOMAIN in acumos-env.sh, and use the chosen
  domain name in the "Install Process" above, in place of "acumos".

* You can install multiple Acumos platforms (e.g. to test federation), just be
  sure to give each a unique domain name as above.

* The latest verified Acumos platform docker images are specified in
  acumos-env.sh. This script will be updated as new versions are released to
  the staging or release registries of the Acumos.org nexus server.
