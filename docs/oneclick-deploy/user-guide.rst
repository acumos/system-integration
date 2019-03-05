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

Deploying the Platform, For the Impatient (TL;DR)
=================================================

NOTICE:

* this process will remove/install software on your host, and configure
  it e.g. firewall and security rules. Only execute this process if you understand
  the implications or are executing the process in a VM/host that you can easily
  re-create.
* by default, the Acumos platform is deployed with service exposure options
  typical for development environments. Production environments and especially
  public environments will need additional planning and restrictions on exposed
  services, that otherwise could expose your host to security risks. FOR TEST
  PURPOSES ONLY

Docker Based Deployment
-----------------------

NOTE: Not all Acumos features will work as expected under docker, so those will
not be deployed. Examples include the new services in support of model training.

To deploy the components that do work under docker, follow the instructions in
the sections below.

Prerequisites for Docker Based Deployment
.........................................

Prerequisites for docker based deployment:

* Deployment is supported only on Ubuntu Xenial (16.04), Bionic (18.04), or
  Centos 7 hosts
* All hostnames or FQDNs specified in environment files must be DNS-resolvable
  (entries in /etc/hosts or in an actual DNS server)
* User running this script

  * has sudo privileges
  * has installed docker per system-integration/tools/setup-docker.sh
  * has added themselves to the docker group (sudo usermod -G docker $USER),
    and re-logged-in to activate docker group membership
  * if deploying in preparation for use by a non-sudo user, has created the
    user account (sudo useradd -m <user>)
  * has cloned or otherwise provided the system-integration repo, in the
    user's home folder
  * has customized or created as needed

    * the main environment file system-integration/AIO/acumos-env
    * ELK-stack environment: see
      system-integration/charts/elk-stack/setup-elk-env.sh as a guide to what
      environment values can be customized. Customize the default values in
      that script, by changing the values after ':-" e.g. to change "true" to
      "false" replace the first line below with the second

      * export ACUMOS_DEPLOY_METRICBEAT="${ACUMOS_DEPLOY_METRICBEAT:-true}"
      * export ACUMOS_DEPLOY_METRICBEAT="${ACUMOS_DEPLOY_METRICBEAT:-false}"

    * MariaDB: as for the ELK_stack, customize
      system-integration/charts/mariadb/setup-mariadb-env.sh

Deploying for Yourself, as a Host Admin (sudo user)
...................................................

If deploying the platform for yourself, run these commands:

  .. code-block:: bash

    cd system-integration/AIO/
    bash setup_prereqs.sh docker <domain> $USER 2>&1 | tee aio_deploy.log
    bash oneclick_deploy.sh 2>&1 | tee -a aio_deploy.log
  ..

  * where:

    * <domain> is the name you want to use for the Acumos portal. This can be a
      hostname or FQDN.

Preparing as a Host Admin, with Platform Deployment as a Normal User
....................................................................

If a Host Admin needs to run the privileged-user steps for a normal user that
will take it from there:

* As the Host Admin, run these commands:

  .. code-block:: bash

    cd system-integration/AIO/
    bash setup_prereqs.sh docker <domain> <user> 2>&1 | tee aio_deploy.log
    cp -r ~/acumos /home/<user>/.
    cp -r ~/system-integration /home/<user>/.
    sudo chmod -R <user>:<user> /home/<user>/acumos
    sudo chmod -R <user>:<user> /home/<user>/system-integration
  ..

  * where:

    * <domain> is the name you want to use for the Acumos portal. This can be a
      hostname or FQDN.
    * <user> use the normal user's account name on the host

* As the normal user, run this command

  .. code-block:: bash

    bash oneclick_deploy.sh 2>&1 | tee -a aio_deploy.log
  ..

When Deployment is Complete
...........................

When deployment has completed, you should see a set of URLs to access the
various platform services. You can also view the file "acumos.url" which will be
in the system-integration/AIO folder (example below)

.. code-block:: bash

  $ cat system-integration/AIO/acumos.url
  Portal: https://acumos.example.com:30443
  Common Data Service: https://acumos.example.com:30443/ccds/swagger-ui.html
  Kibana: http://acumos.example.com:30561/app/kibana
  Nexus: http://acumos.example.com:30881
  Mariadb Admin: http://acumos.example.com:30380
  Kong Admin: http://acumos.example.com:30081

By default, the platform is not configured to require email confirmation of
new accounts, so you can create a new account directly on the Portal home. To
create an account with the Admin role (needed for various platform admin
functions), use the create-user.sh script in the system-integration/AIO folder

Generic Kubernetes Based Deployment
-----------------------------------

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

* Admin ensures their user account is part of the docker group
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

To be added.

Current Release (Boreas)
------------------------

To be added.

Kubernetes-Based Deployment Step-by-Step Guide
==============================================

Prerequisites for each step are described for the step.

Install Host Preparation by Admin
---------------------------------

The script supporting this step is system-integration/AIO/acumos_k8s_prep.sh.

Prerequisites:

* Ubuntu Xenial/Bionic or Centos 7 server
* Admin user account is part of the "docker" group
* Initial basic setup (manual)

  * If you are an Admin and deploying the platform for a normal user, assuming
    the non-sudo user is "acumos"

    .. code-block:: bash

      sudo useradd -m acumos
      mkdir -p ~/acumos/env
      mkdir -p ~/acumos/logs
      mkdir -p ~/acumos/certs
      sudo cp -r ~/acumos /home/acumos/.
      sudo chown -R acumos:acumos /home/acumos/acumos
    ..

This process prepares the host with prerequisites that normal users do not have
permission to arrange. This includes:

* installing software packages
* configuring host settings
* creating folders for host-mapped volumes

The Admin user will follow this process:

* cd to a folder that you want to use as the root of this installation process
* create in that folder a subfolder "acumos" and folders "env", "logs", "certs"
  under it.
* If you want to use a specific/updated/patched system-integration repo clone,
  place that system-integration clone in the install root folder

* Then run the command

  .. code-block:: bash

    bash system-integration/AIO/acumos_k8s_prep.sh <user> <domain> [clone]
  ..

  * user: non-sudo user account (use $USER if deploying for yourself)
  * domain: domain name of Acumos platorm (resolves to this host)
  * clone: if "clone", the current system-integration repo will be cloned.
  *   Otherwise place the system-integration version to be used at
      ~/system-integration

When the process is complete, if you are deploying the platform for yourself,
proceed to the next section. If preparing the platform for a normal user,
the user should execute the process in the next section.

Platform Deployment
-------------------

The script supporting this step is system-integration/AIO/acumos_k8s_deploy.sh.

Prerequisites:

* User workstation is Ubuntu Xenial/Bionic, Centos 7, or MacOS
* acumos_k8s_prep.sh run by a sudo user
* prepare a clone of the system-integration repo in the root folder of
  your user account. This can be a fresh clone or a patched/updated clone.
* As setup by acumos_k8s_prep.sh, make sure you have a folder "acumos" with
  subfolders "env", "logs", and "certs". Put any customized environment files
  and certs there, or use the ones provided by the sudo user that ran
  acumos_k8s_prep.sh

This process deploys the Acumos platform with the options selectable by the
user, e.g.

* any option selectable through the environment files, as prepared by the
  Admin in host preparation

  * acumos-env.sh
  * mariadb-env.sh
  * elk-env.sh

* use of pre-created server and CA certificates, truststore, and keystore

The user will follow this process:

* update environment files for any desired options
* run the commands

* Then run the command

  .. code-block:: bash

    cd ~/system-integration/AIO
    bash acumos_k8s_deploy.sh
  ..

When the process is complete, you will see a set of URLs to the main platform
component/UI features.

Updating Configuration and Components
-------------------------------------

Stopping, Restarting, and Reinstalling
--------------------------------------

Notes on Verified Features
--------------------------

Additional Notes
================


