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
  * has installed docker per system-integration/tools/setup_docker.sh
  * has added themselves to the docker group (sudo usermod -aG docker $USER),
    and re-logged-in to activate docker group membership
  * if deploying in preparation for use by a non-sudo user, has created the
    user account (sudo useradd -m <user>)
  * has cloned or otherwise provided the system-integration repo, in the
    user's home folder
  * has customized or created as needed

    * the main environment file system-integration/AIO/acumos-env
    * ELK-stack environment: see
      system-integration/charts/elk-stack/setup_elk_env.sh as a guide to what
      environment values can be customized. Customize the default values in
      that script, by changing the values after ':-" e.g. to change "true" to
      "false" replace the first line below with the second

      * export ACUMOS_DEPLOY_METRICBEAT="${ACUMOS_DEPLOY_METRICBEAT:-true}"
      * export ACUMOS_DEPLOY_METRICBEAT="${ACUMOS_DEPLOY_METRICBEAT:-false}"

    * MariaDB: as for the ELK_stack, customize
      system-integration/charts/mariadb/setup_mariadb_env.sh

Deploying for Yourself, as a Host Admin (sudo user)
...................................................

NOTE: If you are deploying into an Azure-based VM, pay attention to this
special configuration need for the docker-engine; update the acumos_env.sh
(in system-integration/AIO) script to set the ACUMOS_DEPLOY_DOCKER flag to
"false", which will ensure that the docker-dind service is not installed.
Docker-dind has known issues under Azure.

  .. code-block:: bash

    export ACUMOS_DEPLOY_DOCKER=false
  ..

If deploying the platform for yourself, run these commands:

  .. code-block:: bash

    cd system-integration/AIO/
    bash setup_prereqs.sh docker <domain> $USER 2>&1 | tee aio_deploy.log
    bash oneclick_deploy.sh 2>&1 | tee -a aio_deploy.log
  ..

  * where:

    * <domain> is the name you want to use for the Acumos portal. This can be a
      hostname or FQDN.

  * The commands above include saving of the detailed deployment actions to a
    log file 'deploy.txt'. This can be helpful in getting support from the
    Acumos project team, to overcome issues you might encounter. If you don't
    want to save the log, just leave out the part of the commands above that
    starts with the 'pipe' ('|').


Preparing as a Host Admin, with Platform Deployment as a Normal User
....................................................................

If a Host Admin needs to run the privileged-user steps for a normal user that
will take it from there:

* NOTE: If you are deploying into an Azure-based VM, pay attention to this
  special configuration need for the docker-engine; update the acumos_env.sh
  (in system-integration/AIO) script to set the ACUMOS_DEPLOY_DOCKER flag to
  "false", which will ensure that the docker-dind service is not installed.
  Docker-dind has known issues under Azure.

  .. code-block:: bash

    export ACUMOS_DEPLOY_DOCKER=false
  ..

* As the Host Admin, run these commands:

  .. code-block:: bash

    cd system-integration/AIO/
    bash setup_prereqs.sh docker <domain> <user> 2>&1 | tee aio_deploy.log
  ..

  * where:

    * <domain> is the name you want to use for the Acumos portal. This can be a
      hostname or FQDN.
    * <user> use the normal user's account name on the host

* As the normal user, run this command

  .. code-block:: bash

    bash oneclick_deploy.sh 2>&1 | tee -a aio_deploy.log
  ..

* As described above, if you don't need to save the deploy logs, leave out the
  the part of the commands above that starts with the 'pipe' ('|').


When Deployment is Complete
...........................

When deployment has completed, you should see a success message with a set of
URLs to access the various platform services. You can also view the file
"acumos.url" which will be in the system-integration/AIO folder (example below)

.. code-block:: bash

   You can access the Acumos portal and other services at the URLs below,
   assuming hostname "acumos.example.com" is resolvable from your workstation:

   Portal: https://acumos.example.com
   Common Data Service Swagger UI: https://acumos.example.com/ccds/swagger-ui.html
   Portal Swagger UI: https://acumos.example.com/api/swagger-ui.html
   Onboarding Service Swagger UI: https://acumos.example.com/onboarding-app/swagger-ui.html
   Kibana: http://<IP address of acumos.example.com>:30561/app/kibana
   Nexus: http://<IP address of acumos.example.com>:30881

By default, the platform is not configured to require email confirmation of
new accounts, so you can create a new account directly on the Portal home. To
create an account with the Admin role (needed for various platform admin
functions), use the create_user.sh script in the system-integration/tests folder

Kubernetes Based Deployment
---------------------------

The process below will support deployment under either a generic kubernetes
distribution, or the OpenShift kubernetes distribution. The scripts will detect
which distribution is installed and deploy per the requirements of that
distribution.

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

    $ if [[ "$(id -nG "$USER" | grep docker)" == "" ]]; then sudo usermod -aG docker $USER; fi
  ..

  * if you see "usermod: group 'docker' does not exist", install docker (e.g.
    using setup_docker.sh in the system-integration/tools folder) and run the
    command above again. Once you do not see the message above, logout and re-login.

* execute the following command to install/configure prerequisites, including
  k8s, MariaDB, and the ELK stack, using your user account, and the hostname or
  domain name you will use to access the deployed platform.

  .. code-block:: bash

    $ bash system-integration/AIO/acumos_k8s_prep.sh $USER <domain> 2>&1 | tee aio_prep.log
  ..

* When you see "Prerequisites setup is complete." as the result of the
  command above, execute the following commands to complete platform setup

  .. code-block:: bash

    $ cd system-integration/AIO
    $ bash acumos_k8s_deploy.sh 2>&1 | tee aio_deploy.log
  ..

* As described above, if you don't need to save the deploy logs, leave out the
  the part of the commands above that starts with the 'pipe' ('|').

When deployment has completed, you should see a success message with a set of
URLs to access the various platform services. You can also view the file
"acumos.url" which will be in the system-integration/AIO folder (example below)

.. code-block:: bash

   You can access the Acumos portal and other services at the URLs below,
   assuming hostname "acumos.example.com" is resolvable from your workstation:

   Portal: https://acumos.example.com
   Common Data Service Swagger UI: https://acumos.example.com/ccds/swagger-ui.html
   Portal Swagger UI: https://acumos.example.com/api/swagger-ui.html
   Onboarding Service Swagger UI: https://acumos.example.com/onboarding-app/swagger-ui.html
   Kibana: http://<IP address of acumos.example.com>:30561/app/kibana
   Nexus: http://<IP address of acumos.example.com>:30881

By default, the platform is not configured to require email confirmation of
new accounts, so you can create a new account directly on the Portal home. To
create an account with the Admin role (needed for various platform admin
functions), use the create_user.sh script in the system-integration/tests folder

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

    $ bash system-integration/AIO/acumos_k8s_prep.sh <user> <domain> 2>&1 | tee aio_prep.log
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
    $ bash acumos_k8s_deploy.sh 2>&1 | tee aio_deploy.log
  ..

* As described above, if you don't need to save the deploy logs, leave out the
  the part of the commands above that starts with the 'pipe' ('|').

When deployment has completed, you should see a success message with a set of
URLs to access the various platform services. You can also view the file
"acumos.url" which will be in the system-integration/AIO folder (example below)

.. code-block:: bash

   You can access the Acumos portal and other services at the URLs below,
   assuming hostname "acumos.example.com" is resolvable from your workstation:

   Portal: https://acumos.example.com
   Common Data Service Swagger UI: https://acumos.example.com/ccds/swagger-ui.html
   Portal Swagger UI: https://acumos.example.com/api/swagger-ui.html
   Onboarding Service Swagger UI: https://acumos.example.com/onboarding-app/swagger-ui.html
   Kibana: http://<IP address of acumos.example.com>:30561/app/kibana
   Nexus: http://<IP address of acumos.example.com>:30881

By default, the platform is not configured to require email confirmation of
new accounts, so you can create a new account directly on the Portal home. To
create an account with the Admin role (needed for various platform admin
functions), use the create_user.sh script in the system-integration/tests folder

Release Scope
=============

To be added.

Current Release (Boreas)
------------------------

To be added.

What's included in the AIO tools
................................

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
* acumos_env.sh: environment setup script that is customized as new
  environment parameters get generated (e.g. passwords). Used by various
  scripts in this toolset, to set shell environment variables that they need.
* setup_acumosdb.sh: script that initializes the Acumos database under MariaDB.
* setup_keystore.sh: script that enables use of pre-configured CA and server
  certificates for an Acumos platform, or creation of new self-signed
  certificates.
* docker_compose.sh: Script called by the other scripts as needed, to take
  actions on the set of Acumos docker services. Used by oneclick_deploy.sh and
  clean.sh for docker-based deployments. You can also call this directly e.g.
  to tail the service container logs. See the script for details.
* utils.sh: utility script containing functions used by many of these scripts.
* redeploy_component.sh: Script that allows the redeployment of a single
  component.
* clean.sh: if needed, this script allows a privileged user to remove all
  components and dependencies of the Acumos platform installed by the tools
  above.

In AIO/beats:

* deployment scripts and templates for the Filebeat and Metricbeat services
  as ELK stack components deployed along with the Acumos platform.

In AIO/certs:

* setup_certs.sh: creates self-signed certificates (CA and server), keystore,
  and truststore for use by core platform components.

In AIO/docker/acumos:

* docker-compose yaml files and deployment script for Acumos core components.

In AIO/certs:

* setup_certs.sh: script to create self-signed CA and server certs.
* This folder is also used to stage user-provided certs to be used in Acumos
  platform deployment.

In AIO/docker-engine:

* scripts and templates to deploy docker-in-docker as the docker-engine service
  for k8s-based Acumos platforms, or the docker-engine service on the AIO host

In AIO/docker-proxy:

* scripts and templates for deployment of the docker-proxy core component of the
  Acumos platform

In AIO/elk-stack:

* scripts and templates to deploy the ELK stack core components under docker

In AIO/ingress:

* scripts and templates to deploy the
  `NGINX Ingress Controller for Kubernetes <https://github.com/kubernetes/ingress-nginx>`_,
  and ingress rules for Acumos core components.

In AIO/kong:

* scripts and templates to deploy the Kong service as an ingress controller for
  the Acumos platform, as deployed under docker

In AIO/kubernetes:

* under deployment, kubernetes deployment templates for all system components
* under service, kubernetes service templates for all system components
* under configmap, kubernetes configmap templates for all system components
* under rbac, kubernetes role-based access control templates enabling system
  components to invoke kubernetes cluster operations

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

    * NOTE: Zeppelin deployment is a single, multi-user instance which is
      provided for experimental use in Boreas. Single-user instance deployment
      is coming in the next release (Clio).

In tests:

* peer_test.sh: Peering and marketplace subsciptions setup for two AIO platforms.
  Used to test federation use cases.
* create_peer.sh: Automated setup of a peer relationship between two Acumos
  AIO deployments. Used by peer_test.sh.
* create_user.sh: Automated user provisioning and role assignment. Used by
  scripts in this repo to create default admin accounts. Can also be used to
  create user accounts for testing or platform use.
* create_subscription.sh: creates a federation subscription for all models
  published by a federated Acumos platform.
* bootstrap_models.sh: Model package onboarding via curl, for all models in
  a folder.
* onboard_model.sh: Model package onboarding via curl.
* license_scan.sh: invokes a license scan for a solution, using the Security
  Verification Scanning Service.

In tools:

  * add_host_alias.sh: adds a host alias to an Acumos core component, e.g.
    for hostnames/FQDNs that are not resolvable through DNS.
  * setup_docker.sh: deploys the docker version used for docker-based
    platform deployment and interaction.
  * setup_helm.sh: deploys Helm as a service deployment tool.
  * setup_k8s.sh: deploys a generic k8s cluster.
  * setup_kubectl.sh: deploys and uses the kubectl tool used by other scripts and
    the user to manage and interact with generic k8s based deployments.
  * setup_mariadb_client.sh: deploys the MariaDB client as used by other
    scripts to configure the Acumos database.
  * setup_openshift.sh: deploys an OpenShift Origin 3.11 kubernetes cluster, for
    subsequent Acumos platform deploymet on Centos 7 servers.
  * setup_openshift_client.sh: deploys the OpenShift client (oc) tool
    used by other scripts and users to manage and interact with OpenShift based
    platform deployments.
  * setup_prometheus.sh: deploys the Prometheus monitoring service, with
    Grafana as a data visualization tool, for monitoring the Acumos platform's
    resources at the k8s level. Also deploys Grafana dashboards in the dashboards
    folder.
  * setup_pv.sh: deploys host-based persistent volumes for use with
    docker and k8s-based platform deployments.

Kubernetes-Based Deployment Step-by-Step Guide
==============================================

Prerequisites for each step are described for the step.

Install Host Preparation by Admin
---------------------------------

The script supporting this step is system-integration/AIO/acumos_k8s_prep.sh.

NOTE: If you are deploying into an Azure-based VM, pay attention to the
special configuration need for the docker-engine, as described below.

Prerequisites:

* Ubuntu Xenial/Bionic or Centos 7 server
* All hostnames specified in acumos_env.sh must be DNS-resolvable on all hosts
  (entries in /etc/hosts or in an actual DNS server)
* For deployments behind proxies, set HTTP_PROXY and HTTPS_PROXY in acumos_env.sh
* Admin user running this script has:

  * Installed docker per system-integration/tools/setup_docker.sh
  * Added themselves to the docker group (sudo usermod -aG docker $USER)
  * Logged out and back in, to activate docker group membership

* Initial basic setup (manual)

  * If you are an Admin and deploying the platform for a normal user, assuming
    the non-sudo user is "acumos"

    .. code-block:: bash

      sudo useradd -m acumos
    ..

This process prepares the host with prerequisites that normal users do not have
permission to arrange. This includes:

* installing software packages
* configuring host settings
* creating folders for host-mapped volumes

The Admin user will follow this process:

* 'install root folder' refers to the Admin user's home folder. Installation
  in other root folders is a work in progress, and not yet fully verified.
* create in the install root folder a subfolder "acumos" and folders "env",
  "logs", "certs" under it.
* If you want to use a specific/updated/patched system-integration repo clone,
  place that system-integration clone in the install root folder
* If you are deploying the platform in an Azure VM, update the acumos_env.sh
  (in system-integration/AIO) script to set the ACUMOS_DEPLOY_DOCKER flag to
  "false", which will ensure that the docker-dind service is not installed.
  Docker-dind has known issues under Azure.

  .. code-block:: bash

    export ACUMOS_DEPLOY_DOCKER=false
  ..


* Then run the command

  .. code-block:: bash

    bash system-integration/AIO/acumos_k8s_prep.sh <user> <domain> [clone]
  ..

  * user: non-sudo user account (use $USER if deploying for yourself)
  * domain: domain name of Acumos platorm (resolves to this host)
  * clone: if "clone", the current system-integration repo will be cloned.
  * Otherwise place the system-integration version to be used at
    ~/system-integration

When the process is complete, acumos_k8s_prep.sh will have copied the
updated system-integration clone and environment files to the platform
deployment user's home folder. If you are deploying the platform for yourself,
proceed to the next section. If preparing the platform for a normal user,
the user should execute the process in the next section.

Platform Deployment
-------------------

The script supporting this step is system-integration/AIO/acumos_k8s_deploy.sh.

Prerequisites:

* User workstation is Ubuntu Xenial/Bionic, Centos 7, or MacOS
* acumos_k8s_prep.sh run by a sudo user
* As setup by acumos_k8s_prep.sh, make sure you have a folder "acumos" with
  subfolders "env", "logs", and "certs". Put any customized environment files
  and certs there, or use the ones provided by the sudo user that ran
  acumos_k8s_prep.sh

This process deploys the Acumos platform with the options selectable by the
user, e.g.

* any option selectable through the environment files, as prepared by the
  Admin in host preparation; environment files that can be customized include:

  * ~/acumos/env/acumos_env.sh
  * ~/acumos/env/mariadb_env.sh
  * ~/acumos/env/elk_env.sh
  * ~/system-integration/AIO/mlwb/mlwb_env.sh
  * NOTE

    * since acumos_k8s_prep.sh by default will have deployed MariaDB,
      Nexus, and the ELK stack core, do not modify the related environment values
      unless you have set ACUMOS_DEPLOY_MARIADB, ACUMOS_DEPLOY_NEXUS, or
      ACUMOS_DEPLOY_ELK to 'false' in acumos_env.sh
    * a detailed description of the customizable environment values is not
      provided here, but the Acumos community can assist you with any support
      questions you may have via the
      `Acumos Community mail list <https://lists.lfai.foundation/g/acumosai-community>`_

* use of pre-created server and CA certificates, truststore, and keystore

  * Note that by default the setup_keystore.sh script will create self-signed
    certs, unless the ~/acumos/certs folder contains pre-arranged certs, plus a
    PKCS12 or JKS format keystore, and a JKS format truststore that are
    created per the process in setup_keystore.sh.

The user will follow this process:

* update environment files for any desired options
* Then run the command

  .. code-block:: bash

    cd ~/system-integration/AIO
    bash acumos_k8s_deploy.sh
  ..

When the process is complete, you will see a set of URLs to the main platform
component/UI features, as described above.

Updating Configuration and Components
-------------------------------------

Changes to the configuration can be applied as described in the previous section.
Note that if you are making changes to the configuration of a deployed platform,
some changes may break some aspects of the platform, so be careful.

The most commonly updated configuration items include:

* in acumos_env.sh

  * component versions
  * component hosts and ports, e.g. for reuse of previously deployed components,
    e.g. a shared docker-engine, docker registry, MariaDB, Nexus, or ELK stack service
  * component credentials (user and/or password)
  * ports, to avoid conflict with other deployments in the same environment
  * Nexus repo details
  * HTTP proxy
  * CDS (Common Dataservice) database version
  * model onboarding tokenmode
  * operator ID
  * kubernetes namespace
  * Persistent Volume options

* docker-compose templates in AIO/docker/acumos or kubernetes templates in
  AIO/kubernetes

  * Note: make sure the template modifications are compatible with previously
    deployed components, and the version of the related Acumos component you
    are deploying/re-deploying

Stopping, Restarting, Redeploying
---------------------------------

Note: the following sections assume that you have deployed the Acumos platform
from the system-integration folder in your user home directory, i.e. "~/".

Docker-Based Deployments
++++++++++++++++++++++++

To stop components running under docker and remove the containers, execute the
following commands from the "docker" folder related to the type of component,
referencing the related docker-compose yaml file as "<yml>":

.. code-block:: bash

  cd ~/system-integration/<docker folder>
  source ~/system-integration/AIO/acumos_env.sh
  docker-compose -f acumos/<yml> down
..

The related docker folders are:

* AIO/docker, for Acumos core components azure-client, common-data-svc,
  dsce (AcuCompose), federation, kubernetes-client, microservice-generation,
  onboarding, portal-be, portal-fe, sv-scanning
* AIO/docker-proxy/docker, for the docker-proxy core component
* AIO/mlwb/docker, for the MLWB components
* AIO/nexus/docker, for nexus
* AIO/mariadb/docker, for mariadb
* AIO/kong/docker, for kong
* AIO/elk-stack/docker, for the core ELK-stack components elasticsearch,
  logstash, kibana
* AIO/beats/docker, for the "beats" components filebeat, metricbeat

To restart these components, e.g. after updating the related configuration files,
issue the following command:

.. code-block:: bash

  cd ~/system-integration/<docker folder>
  source ~/system-integration/AIO/acumos_env.sh
  docker-compose -f acumos/<yml> up -d --build
..

If you want to automatically stop and redeploy the components in one command:

* for Acumos core components (azure-client-service, cds-service, dsce-service,
  federation-service, kubernetes-client-service, msg-service, onboarding-service,
  portal-be-service, portal-fe-service, sv-scanning-service)

  .. code-block:: bash

    bash ~/system-integration/AIO/redeploy_component.sh <component>
  ..

* for the other components, a specific redeployment script is provided in the
  related folder (docker-proxy, mlwb, nexus, mariadb, kong, elk-stack, beats)

  .. code-block:: bash

    bash ~/system-integration/AIO/<folder>/setup_*.sh  ~/system-integration/AIO/
  ..

Kubernetes-Based Deployments
++++++++++++++++++++++++++++

Because kubernetes-based components may depend upon a variety of other
kubernetes resources specific to them or shared with other components (e.g.
configmaps, secrets, PVCs), simply redeploying the specific
components after any required configuration updates is recommended.

The configuration files specific the components are generally under a subfolder
"kubernetes", and are specific to the type of resource (e.g. service, deployment,
configmap, secret, PVC, etc). Once you have updated these as needed, you can'
redeploy the component and any resources specific to it (not shared) via the
command:

* for core components under AIO/kubernetes/deployment, using the component names
  per the "app:" value in the related deployment template (azure-client, cds,
  dsce, federation, kubernetes-client, msg, onboarding, portal-be, portal-fe,
  sv-scanning):

  .. code-block:: bash

    bash ~/system-integration/AIO/redeploy_component.sh <component>
  ..

* for the other components, running the related "setup_*.sh" command as described
  for docker

If you just need to stop a component, use the following command and reference the
related "app" label:


.. code-block:: bash

  kubectl delete deployment -n acumos -l app=<app>
..

You can see all the component-related "app" labels via the command:

.. code-block:: bash

  kubectl get deployment -n acumos -o wide
..

After stopping the component, you can redeploy it as needed using the methods
described above.

Logs Location
=============

Logs are easily accessible on the AIO host under /mnt/acumos directory. That
directory is mounted by most Acumos components as their log directory.

Verified Features
=================

The `Acumos wiki <https://wiki.acumos.org/display/OAM/System+Integration>`_
describes the set of tests that are regularly executed as part of AIO
feature development.
