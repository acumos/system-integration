<!---
.. ===============LICENSE_START=======================================================
.. Acumos CC-BY-4.0
.. ===================================================================================
.. Copyright (C) 2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
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
-->

# All In One (AIO) for Acumos

These scripts build an all-in-one instance of Acumos, with the database,
Nexus repositories and docker containers all running on a single virtual machine.

## Contents

* oneclick_deploy.sh: the script you will run as “bash oneclick_deploy.sh”.
* acumos-env.sh: environment setup script that will get customized as new env parameters get generated (e.g. passwords). Used by oneclick_deploy.sh and clean.sh. Post-install, you can get the mysql root and user passwords from this if you want to do any manual database operations, e.g. see what tables/rows are created.
* clean.sh: script you can run as “bash clean.sh” to remove the Acumos install, to try it again etc.
* cmn-data-svc-ddl-dml-mysql-1.14.sql: Common Dataservice database setup script. Used by oneclick_deploy.sh.
* docker-compose.sh: Script called by the other scripts as needed, to take action on the set of Acumos docker services. Used by oneclick_deploy.sh and clean.sh. You can also call this directly e.g. to tail the service container logs. See the script for details.
* docker-compose.yaml: The docker services that will be acted upon, per the options passed to docker-compose.sh.

## Step-by-step guide

### Prerequisites:
This guide assumes:

* you are deploying all Acumos Portal components on an Ubuntu Xenial desktop/server, with at least 16GB of RAM (recommended). The Acumos portal as deployed by this script on bare metal consumes currently about 6GB of RAM, so may be deployable in hosts with less than 16GB RAM.
* you are deploying an AIO instance to a host you will call "acumos" and resolve via your hosts file, for accessing the Acumos portal via your browser or for model onboarding
  * Note this can be another physical host, or a VM running on your workstation
* you will access that AIO instance from your workstation

### Install Process

The notes below provide an overview of the default installation process. Note these scripts are a work in progress, and not all Acumos portal functions may work correctly at this time. See "Verified Features" below for a summary of what's been verified to work, at least in the test environments where this has been used so far.

1. Open a shell session (bash recommended) on the host where you want to install Acumos, and clone the system-integration repo:
   * git clone https://gerrit.acumos.org/r/system-integration

1. In the system-integration/AIO folder, run the following command:
   * bash oneclick_deploy.sh
   * The deployment will take 5-20 minutes depending upon whether this is the first time you have run this command before, and have pre-cached the Acumos docker images.

1. When the deployment is complete, you will need to complete one Hippo CMS setup step manually, so that all Acumos portal content is displayed correctly. This will be automated asap, but for now follow these steps:
   * In your browser goto the Hippo CMS component at http://acumos:9080 and login as "admin/admin"
   * Browse to http://acumos:9080/cms/console (there's no direct link from the CMS home screen)
   * One the left, click the + at "hst:hst" and then also at "hst:hosts"
   * Right-click the "dev-env" entry and select "copy node", and enter the name "aio" (you can use any name you want here, it doesn't matter), then click "OK"
   * Click the + at the new "aio" entry, and the same for the nodes as they appear: "com", "azure", "cloudapp", "eastus"
   * Right-click on the "acumos-dev1-vm01-core" entry and select "move node". In the "Move Node" dialog, select the "aio" node, enter "acumos" at "To", and click "OK"
   * On the upper right, select the "Write changes to repository" button

1. So that the default portal domain name "acumos" will resolve on your workstation (from which you will access the portal via your browser), add the following line to your workstation's hosts file:
   * "\<ip address of your AIO host\> acumos"

1. You should now be able to browse to [https://acumos](https://acumos), and
   * register new user accounts, etc
   * If you get a browser warning, just accept the self-signed cert and proceed. Note: use of the Chrome browser is recommended, as it puts fewer roadblocks to accessing sites with self-signed certs.

## Stopping, restarting, re-installing

You can stop all the Acumos components (e.g. to suspend/shutdown your host) without losing their databases via the command:
* sudo bash docker-compose.sh stop

Restart the services later using the following command (note it may take a few minutes for all to be active):
* sudo bash docker-compose.sh stop

You can clean the installation (including all data) and optionally reinstall using the sequence below:
* bash clean.sh
* bash oneclick_deploy.sh

## Verified Features

The following Acumos portal workflows and related features have been verified as working so far. This list will be updated as more workflows are verified.
* new user registration and login
* portal web page asset integration through Hippo CMS (e.g. user guides under "On-Boarding Model")
* model onboarding via command line (scikit-learn, python/tensorflow)
* federated peer relationship creation via portal

### Notes on Verified Features

#### User registration and login

Currently there is no default user with the "admin" role, as needed e.g. to setup federation (see below). A test script to automate user account creation and role assignment has been included in this repo. See create-user.sh for info and usage. For an example of this script in use, see peer-test.sh below.

#### Model onboarding via command line

Currently this is verified by posting a model package to the onboarding API, as toolkit clients will do when installed. A script and set of sample models to automate this are in development, and will be added to Acumos repos soon.

#### Federation

Oneclick_deploy.sh will automatically create a "self" peer as required by the federation-gateway.

If you want to deploy two Acumos AIO instances to test federation, see these scripts for info and usage:
* peer-test.sh: installs and peers two Acumos AIO instances, on two hosts
* create-peer.sh: used by peer-test.sh. You can call this script directly to add a peer to an existing Acumos portal.

You can also manually create a federated peer:
* If you have not created an admin user, run create-user.sh as above to create one. 
* Login to the portal as the admin user
* Under the "SITE ADMIN" page, select "Add Peer", enter these values, and select "Done":
   * Peer Name: FQDN of the peer
   * Server FQDN: the DNS-resolvable FQDN or IP address of the peer
   * API Url: http://\<FQDN of the peer\>:\<federation-gateway port from acumos-env.sh\>
   * Peer Admin Email: any valid email address
* Verify that the peer relationship was setup via executing these commands on the AIO host
   * source acumos-env.sh
   * curl -vk --cert certs/acumos.crt --key certs/acumos.key <API Url as above>
* You should see details of the HTTPS connection followed by
  * {"error":null,"message":"available public solution for given filter","content":[...]}
* This indicates that the request for "solutions" was accepted. "..." will either be "" (no solutions) or a JSON blob with the solution details.


### Features Pending Verification

* model onboarding via web
* model private sharing with user
* model publication to local marketplace
* model publication to federated marketplace
* federated subscription to public marketplace models
* model launch
* design studio
* ...

## Additional Notes

The scripts etc in this repo install Acumos with a default set of values for key environment variables. See acumos-env.sh for these defaults. You should be modify any explicit value (not variables) defined there, but some additional steps may be needed for the installed portal to work with the updated values. For example:
* To use a a non-default domain name for the acumos AIO server (default: acumos), change ACUMOS_DOMAIN in acumos-env.sh, and use the chosen domain name in the "Install Process" above, in place of "acumos".
* You can install multiple Acumos portals (e.g. to test federation), just be sure to give each a unique domain name as above.
* The Hippo CMS manual config process above can also work for any FQDN, with the changes:
  * Under "hst:hosts", replace the host domain name elements at each level in the domain name, with the corresponding level name for your chosen FQDN, and move/rename the "acumos-dev1-vm01-core" by selecting to the next-to-last level (e.g. "example", if your FQDN is "acumos.example.com"), and naming the node as the last subdomain name (e.g. "acumos", if your FQDN is "acumos.example.com")
* The latest verified Acumos platform docker images are specified in acumos-env.sh. This script will be updated as new versions are released to the stable or release repos of the Acumos.org nexus server.
* As of this version, only a clean install is supported by this script, thus for each re-install you will need to recreate users, re-onboard models, etc. Test scripts to simplify this process will be provided asap.
* If you want to test a different version of the common-dataservice component, you will need to copy the corresponding ".sql" script from the "cmn-data-svc-server/db-scripts/" folder in the common-dataservice repo, e.g. for CDS version 1.14.1, the file "cmn-data-svc-ddl-dml-mysql-1.14.sql". This is the current version included in this folder. If you select a different version, copy that file into this folder and update the related values in acumos-env.sh.

This is an early version of this script. Various workarounds and incompletely verified functions may be included. Some examples:
* For some models, the container image build process depends upon a Python Package Index (PyPI) server which contains python modules needed in the microservice build process. The current version of these scripts uses a local copy of the development PyPI index, and setup of a web server (see function setup_localindex in oneclick_deploy.sh) to serve the modules. ASAP, this script will be verified with the official LF PyPI server. 
