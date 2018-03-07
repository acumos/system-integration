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

# All In One for Acumos

These scripts build an all-in-one instance of Acumos, with the database,
Nexus repositories and docker containers all running on a single virtual machine.

## Contents

* oneclick_deploy.sh: the script you will run as “bash oneclick_deploy.sh”.
* acumos-env.sh: environment setup script that will get customized as new env parameters get generated (e.g. passwords). Used by oneclick_deploy.sh and clean.sh. You can get the mysql root and user passwords from this if you want to do any manual database operations, e.g. see what tables/rows are created.
* clean.sh: script you can run as “bash clean.sh” to remove the Acumos install, to try it again etc.
* cmn-data-svc-ddl-dml-mysql-1.13.sql: Common Dataservice database setup script. Used by oneclick_deploy.sh.
* docker-compose.sh: Script called by the other scripts as needed, to take action on the set of Acumos docker services. Used by oneclick_deploy.sh and clean.sh. You can also call this directly e.g. to tail the service container logs. See the script for details.
* docker-compose.yaml: The docker services that will be acted upon, per the options passed to docker-compose.sh.

## Step-by-step guide

### Prerequisites:
This guide assumes:

* you are deploying all Acumos Portal components on an Ubuntu Xenial desktop/server, with a significant amount of RAM (e.g. 64GB, but the minimum will be documented here after testing and container RAM usage optimization)
* you are deploying an AIO instance to a host you will call "acumos" and resolve via your hosts file
Note this can be another physical host, or a VM running on your workstation
* you will access that AIO instance from your workstation

### Install Process

1. Open a shell session (bash recommended) on the host where you want to install Acumos, and clone the system-integration repo:
   * git clone https://gerrit.acumos.org/r/system-integration

1. If you are deploying to a host that does not have a DNS-registered FQDN
   * Add the following line to your workstation's hosts file:
     * \<ip address of your AIO host\> \<name you want to use when browsing to that host\>, e.g. "10.0.0.2 acumos"
   * If you want to use the domain name setup for the Acumos Portal out-of-the-box (as currently implemented), add this to your hosts file "\<ip address of your AIO host\> acumos-dev1-vm01-core.eastus.cloudapp.azure.com"
     * Note that this approach may not work fully; some CMS content (e.g. in the On-Boarding By Command Line view) does not populate correctly; this is being investigated.

1. In the system-integration/AIO folder, run the following command:
   * bash oneclick_deploy.sh
     * The deployment will take 5-20 minutes depending upon whether this is the first time you have run this command before, and have pre-cached the Acumos docker images.

1. When the deployment is complete, if you want to use a FQDN different from the default acumos-dev1-vm01-core.eastus.cloudapp.azure.com, you will need to configure Hippo CMS to use your AIO "acumos" service instance (this part will be automated asap):
   * In your browser goto the Hippo CMS component at http://acumos:9080 and login as "admin/admin"
   * One the left, click the + at "hst:hst" and then also at "hst:hosts"
   * Right-click the "dev-env" entry and select "copy node", and enter the name "aio" (you can use any name you want here, it doesn't matter)
   * Click the + at the new "aio" entry, and the same for the nodes as they appear: "com", "azure", "cloudapp", "eastus"
   * Right-click on the "acumos-dev1-vm01-core" entry and select "move node". In the "Move Node" dialog, select the "aio" node, enter "acumos" at "To", and click "OK".
     * The process above can also work for any FQDN with the changes: At each level in the domain name, replace the corresponding name with that for your chosen FQDN, and move/rename the "acumos-dev1-vm01-core" by selecting to the next-to-last subdomain name (e.g. "example", if your FQDN is "acumos.example.com"), and naming the node as the last subdomain name (e.g. "acumos", if your FQDN is "acumos.example.com")
   * On the upper right, select the "Write changes to repository" button

1. You should now be able to browse to [http://acumos](http://acumos) and create a new account as an Acumos user.
