
.. ===============LICENSE_START=======================================================
.. Acumos CC-BY-4.0
.. ===================================================================================
.. Copyright (C) 2017-2020 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
.. ===================================================================================
.. This Acumos documentation file is distributed by AT&T and Tech Mahindra
.. under the Creative Commons Attribution 4.0 International License (the "License");
.. you may not use this file except in compliance with the License.
.. You may obtain a copy of the License at
..
.. http://creativecommons.org/licenses/by/4.0
..
.. This file is distributed on an "AS IS" BASIS,
.. WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
.. See the License for the specific language governing permissions and
.. limitations under the License.
.. ===============LICENSE_END=========================================================

================================

================================
System Integration Release Notes
================================

--------------------------
Version 4.0.0, 10 Jun 2020
--------------------------

* Helm Chart refactor

  * Separate Helm chart for each Acumos component

    * separate charts for core and non-core components
    * separate z2a structure for Acumos plugins (currently only MLWB is supported)

  * Consolidate and sanitize key/values into ``global_value.yaml`` file
  * Add secrets to Helm charts for secure communication between k8s cluster components

* Zero-to-Acumos (z2a) Initial Release

  * Acumos installation/configuration automation
  * Flow (process) based model

      - Flow-1 - build k8s cluster and install Acumos on a single VM
      - Flow-2 - install Acumos on a pre-built k8s cluster

  * z2a documentation

--------------------------
Version 3.0.3, 19 Dec 2019
--------------------------

* `ACUMOS-3862: Update to weekly assembly Acumos_Clio_1912161300 <https://jira.acumos.org/browse/ACUMOS-3862>`_

  * `6162: Update to weekly assembly Acumos_Clio_1912161300 <https://gerrit.acumos.org/r/#/c/system-integration/+/6162/>`_

--------------------------
Version 3.0.2, 19 Dec 2019
--------------------------

* `ACUMOS-3842: Fix Azure-AKS deployment <https://jira.acumos.org/browse/ACUMOS-3842>`_

  * `6159: Support Azure CLI env for install <https://gerrit.acumos.org/r/#/c/system-integration/+/6159/>`_
  * `6132: Federation via LoadBalancer for Azure-AKS <https://gerrit.acumos.org/r/#/c/system-integration/+/6132/>`_
  * `6117: Fix Azure-AKS deployment regression <https://gerrit.acumos.org/r/#/c/system-integration/+/6117/>`_

--------------------------
Version 3.0.1, 10 Dec 2019
--------------------------

* `ACUMOS-3755: Add docker-compose files for License Profile and RTU editors <https://jira.acumos.org/browse/ACUMOS-3755>`_
* `ACUMOS-3710: AIO update for Acumos_Clio_1911291230 <https://jira.acumos.org/browse/ACUMOS-3710>`_
* `ACUMOS-3658: mlwb-notebook - not starting with AIO <https://jira.acumos.org/browse/ACUMOS-3658>`_
* `ACUMOS-3648: Pods must be capable of running in non-privileged mode <https://jira.acumos.org/browse/ACUMOS-3648>`_
* `ACUMOS-3469: RTU Editor as service <https://jira.acumos.org/browse/ACUMOS-3469>`_
* `ACUMOS-3208: Improved support for multi-node k8s clusters and component distribution <https://jira.acumos.org/browse/ACUMOS-3208>`_
* `ACUMOS-3205: Platform deployment usability/reliability enhancements <https://jira.acumos.org/browse/ACUMOS-3205>`_
* `ACUMOS-3177: ML Workbench Model Mapping Service <https://jira.acumos.org/browse/ACUMOS-3177>`_
* `ACUMOS-3134: Jenkins as a workflow engine as a standing or on-demand k8s service <https://jira.acumos.org/browse/ACUMOS-3134>`_
* `ACUMOS-3133: Migrate Solution/Pipeline deployment to Jenkins-based process <https://jira.acumos.org/browse/ACUMOS-3133>`_

--------------------------
Version 3.0.0, 13 Sep 2019
--------------------------

* monitoring resource utilization in kubernetes (`ACUMOS-3069 <https://jira.acumos.org/browse/ACUMOS-3069>`_)
* Monitor resource usage in K8 (`ACUMOS-3162 <https://jira.acumos.org/browse/ACUMOS-3162>`_)

............................
All-in-One (OneClick Deploy)
............................

---------------------------
Version 2.4.0, 15 Aug 2019
---------------------------

This release adds final enhancements to the Boreas maintenance release.

* `4851: Boreas maintenance release wrap-up <https://gerrit.acumos.org/r/#/c/system-integration/+/4851/>`_

  * `ACUMOS-3212 Boreas maintenance release <https://jira.acumos.org/browse/ACUMOS-3212>`_

    * Includes these enhancements:

      * portal-be: enable publication feature with AIO setup
      * Update to release assembly Acumos_1907311600
      * Support platform deployment for k8s cluster tenants

        * minimize nodeport use
        * enable dynamic nodeport assignment
        * merge prep scripts to minimize process variance
        * select whether to create PVc
        * select whether to bind PVCs to specific PVs
        * reorder component deployments to ensure dependencies
        * make ingress controller / ingress object creation optional
        * clean resources specifically instead of deleting namespaces

      * Update clean.sh
      * Support prep|setup|clean action in all component scripts
      * Use docker:18-dind to avoid issues with 19-dind
      * Add qanda element to portal-be springenv
      * Parameterize wait times
      * Pre-pull images
      * Update user guide
      * Add aio_k8s_deployer (containerized k8s deployment tool)
      * Update AIO support in OpenShift (NOTE: WIP for ingress control)

---------------------------
Version 2.3.0, 11 July 2019
---------------------------

This release completes the Boreas maintenance release, to the extent that open
issues and work in progress have been completed.

* `4374: Integrate MLWB components <https://gerrit.acumos.org/r/#/c/system-integration/+/4374/>`_

  * Delivered JIRA items

    * `ACUMOS-2194: Integrate Jupyter notebook with Acumos Portal <https://jira.acumos.org/browse/ACUMOS-2194>`_
    * `ACUMOS-2491: Integrate Nifi with Acumos Portal <https://jira.acumos.org/browse/ACUMOS-2491>`_
    * `ACUMOS-2714: Deploy security-verification component <https://jira.acumos.org/browse/ACUMOS-2714>`_
    * `ACUMOS-2715: Support Helm use in Openshift deployments <https://jira.acumos.org/browse/ACUMOS-2715>`_
    * `ACUMOS-2716: Add option for docker-on-host to address Azure-k8s issues <https://jira.acumos.org/browse/ACUMOS-2716>`_
    * `ACUMOS-2717: Update to weekly assembly Acumos_1904021700 <https://jira.acumos.org/browse/ACUMOS-2717>`_
    * `ACUMOS-2718: Add input parameter check and usage help to scripts <https://jira.acumos.org/browse/ACUMOS-2718>`_
    * `ACUMOS-2721: Add scripts enabling redeployment of specific components <https://jira.acumos.org/browse/ACUMOS-2721>`_
    * `ACUMOS-2871: Update to weekly assembly Acumos_1904301100 <https://jira.acumos.org/browse/ACUMOS-2871>`_

  * Additionally delivers enhancements

    * Images per Boreas release assembly
    * more complete parameterization of templates
    * configuration of mail service
    * general refactoring and updates for design consistency/reliability
    * improve support for cluster-externally deployed components
    * align ELK-stack and beats deployment with azure-k8s templates etc
    * add log level option for all springboot components
    * add user to docker group
    * add option to cleanup/re-pull docker images on component redeploy
    * replace kong with nginx ingress controller for k8s
    * fix lack of delete privilege for Nexus RW user
    * enable artifact overwrite ("redeploy") in Nexus
    * customize catalog names to avoid conflict between Acumos platforms
    * add ELK-client deployment
    * update demo Jupyter notebook
    * add tests/delete_user.sh
    * add tests/license_scan.sh
    * update test scripts for new catalog based publication design
    * add tools/setup_k8s_stack.sh
    * add tools/trust_cert.sh

----------------------------
Version 2.2.0, 23 April 2019
----------------------------

This release completes the planned work for the Boreas release, minus any items
not delivered so far and on the candidate list for deferral to Clio. Further
releases in Boreas will align the AIO tools with the latest weekly releases,
address bugs, and any remaining items that can't be deferred.

* `Release 2.2.0 <https://gerrit.acumos.org/r/#/c/4231/>`_
* `Update to weekly assembly Acumos_1904021700 <https://gerrit.acumos.org/r/#/c/4089/>`_

  * Deliver JIRA items

    * `ACUMOS-2714: Deploy security-verification component <https://jira.acumos.org/browse/ACUMOS-2714>`_
    * `ACUMOS-2715: Support Helm use in Openshift deployments <https://jira.acumos.org/browse/ACUMOS-2715>`_
    * `ACUMOS-2716: Add option for docker-on-host to address Azure-k8s issues <https://jira.acumos.org/browse/ACUMOS-2716>`_
    * `ACUMOS-2717: Update to weekly assembly Acumos_1904021700 <https://jira.acumos.org/browse/ACUMOS-2717>`_
    * `ACUMOS-2718: Add input parameter check and usage help to scripts <https://jira.acumos.org/browse/ACUMOS-2718>`_
    * `ACUMOS-2721: Add scripts enabling redeployment of specific components <https://jira.acumos.org/browse/ACUMOS-2721>`_

----------------------------
Version 2.1.0, 29 March 2019
----------------------------

This release is the first step in the refactoring of the AIO toolset to support
these goals:

* separation of user roles for target hosts (admin vs user)
* Helm-based component deployment
* discrete deployment of prerequisites, supplemental components, and core
  components

The process for deploying the AIO platform has changed. Please review the
`One Click Deploy User Guide <https://docs.acumos.org/en/latest/submodules/system-integration/docs/oneclick-deploy/index.html>`_
for updated instructions.

* `Fix release notes link <https://gerrit.acumos.org/r/#/c/4047/>`_
* `AIO upgrade to CDS 2.0 <https://gerrit.acumos.org/r/#/c/3897/>`_

  * Delivers JIRA items

    * `ACUMOS-2601: AIO upgrade to CDS 2.0 <https://jira.acumos.org/browse/ACUMOS-2601>`_
    * `ACUMOS-2587: Deploy MariaDB via Helm <https://jira.acumos.org/browse/ACUMOS-2587>`_
    * `ACUMOS-2360: Ability to Re-Use Jupyter native capabilities <https://jira.acumos.org/browse/ACUMOS-2360>`_
    * `ACUMOS-2365: AIO deploys new ML Workbench components <https://jira.acumos.org/browse/ACUMOS-2365>`_
    * `ACUMOS-2571: Deploy Zeppelin <https://jira.acumos.org/browse/ACUMOS-2571>`_
    * `ACUMOS-2572: Helm chart for Zeppelin <https://jira.acumos.org/browse/ACUMOS-2572>`_
    * `ACUMOS-2331: Deploy JupyterHub <https://jira.acumos.org/browse/ACUMOS-2331>`_
    * `ACUMOS-2334: Helm chart for JupyterHub <https://jira.acumos.org/browse/ACUMOS-2334>`_
    * `ACUMOS-2126: Expanded uses for docker-proxy <https://jira.acumos.org/browse/ACUMOS-2126>`_
    * `ACUMOS-2121: User-level authentication for docker-proxy <https://jira.acumos.org/browse/ACUMOS-2121>`_
    * `ACUMOS-2122: Authenticate docker-proxy users as Acumos platform users <https://jira.acumos.org/browse/ACUMOS-2122>`_
    * `ACUMOS-2639: acumos AIO sudo/non-sudo install fails <https://jira.acumos.org/browse/ACUMOS-2639>`_
    * `ACUMOS-2145: setup_k8s.sh compatibility with Ubuntu 18.04 <https://jira.acumos.org/browse/ACUMOS-2145>`_

  * Refactor into prereqs script (for admin) and deploy script for user
    (non-sudo)
  * Add prep/deploy wrapper scripts for admin and normal user
  * Add Jupyter, Zeppelin, and NiFi baseline deploy
  * Deploy MariaDB and Elk via Helm
  * Reduce use of nodeports; route external access thru kong if possible
  * Address public cloud use case (hostname different from domain name)
  * Update user guide
  * Add acumos_auth.py as 1st pass on user-level auth for docker-proxy
  * Add docker-proxy README.md
  * Add kong-configure job to secure kong admin setup
  * Refocus peer-test.sh to peer relationship/subscription role
  * Add add-host-alias.sh to update federation etc hosts aliases
  * Add acumos_auth.py to docker-proxy service

* `ACUMOS-2049: system-integration toolset use by non-admin users <https://jira.acumos.org/browse/ACUMOS-2049>`_

  * Delivers Jira items

    * `ACUMOS-2050: Platform deployment by k8s tenants <https://jira.acumos.org/browse/ACUMOS-2050>`_

  * break out elk-stack components for separate deployment
  * script host introspection (k8s tenant machine, or target host)
  * refactor all scripts to use kubectl/oc from cluster-remote machine
  * differentiate k8s user role (admin or tenant)
  * expand acumos-env.sh values set in oneclick_deploy.sh
  * use "source" vs "bash" internally to reuse env across scripts
  * avoid building docker images (tenants can't use non-secure registries)
  * remove unneeded OUTPUT and WEBONBOARDING PVs
  * make clean.sh independent of acumos-env.sh, improve reliability
  * only create PVs if the user is an admin
  * use configmaps where possible to avoid need for PV-staged config data
  * add ACUMOS_MARIADB_VERSION env variable
  * avoid re-configuration of user's workstation where possible
  * migrate tools from kubernetes-client repo

* `ACUMOS-2512: Move End User Guides Back to Component Repos so Projects have sole control <https://jira.acumos.org/browse/ACUMOS-2512>`_

  * `Add oneclick-deploy content <https://gerrit.acumos.org/r/#/c/3770/>`_

* `ACUMOS-2424: AIO support for user-supplied CA and server certs <https://jira.acumos.org/browse/ACUMOS-2424>`_

  * `AIO support for user-supplied CA and server certs <https://gerrit.acumos.org/r/#/c/3679/>`_

------------------------------
Version 2.0.1, 23 January 2019
------------------------------

This is the first draft release for Acumos Boreas.

* `ACUMOS-2301: Oneclick deployment of Acumos on OpenShift <https://jira.acumos.org/browse/ACUMOS-2301>`_

  * `Fix reference to federation-service <https://gerrit.acumos.org/r/#/c/3629/>`_

    * Fix missed bug in the last commit. Portal-BE needs to reference
      federation-service by domain name rather than internal name, since it
      may be deployed outside the local cluster and thus is exposed at a
      nodePort, for which using the cluster-internal name does not work
    * Also corrected other issues impacting platform redeployment
    * Removed subscription creation from peer-test.sh (now a separate script)
    * Fixed bugs in create-peer.sh and create-subscription.sh

  * `Oneclick deployment of Acumos on OpenShift <https://gerrit.acumos.org/r/#/c/3504/>`_

    * include changes for
      `ACUMOS-2150: Improve docker/prereqs checks and setup <https://jira.acumos.org/browse/ACUMOS-2150>`_
    * also address bugs

      * `ACUMOS-2111: AIO uses staging instead of release registry for Athena docker images <https://jira.acumos.org/browse/ACUMOS-2111>`_
      * `ACUMOS-2028: EOF impacts size variable <https://jira.acumos.org/browse/ACUMOS-2028>`_
      * `ACUMOS-2029: References to email to be replaces by environment variable <https://jira.acumos.org/browse/ACUMOS-2029>`_
      * `ACUMOS-2030: Irrelevant reference to nexus-service in /etc/hosts <https://jira.acumos.org/browse/ACUMOS-2030>`_
      * `ACUMOS-2051: Support for PVCs <https://jira.acumos.org/browse/ACUMOS-2051>`_

    * add setup_openshift.sh and setup_openshift_client.sh
    * reintroduce docker-service via docker-dind
    * Connect kong to kong-database directly
    * Allow user to set target namespace
    * Simplify install reset
    * Add Centos-specific prereqs and cleanup
    * Remove host installation of docker for k8s/OpenShift
    * Add option for generic k8s or OpenShift installs
    * Add ELK option for docker-compose to start/stop
    * use "oc" in place of "kubectl" for OpenShift
    * Improve method of determining primary IP address
    * add support for Ubuntu 18.04
    * for Centos, use docker config from /root
    * replace use of "~" with $HOME
    * add K8S_DIST to acumos-env.sh
    * refactor to separate core components from non-core
    * migrate host-installed components (e.g. mariadb) to docker
    * build local images for customization
    * store persistent data in PV/PVC under k8s
    * create resources (e.g. PV, PVC) using ACUMOS_NAMESPACE
    * address OpenShift-specific constraints e.g. for security
    * support Linux, Mac, Windows for OpenShift-CLI client
    * update other tools to be compatible with the changes
    * align designs where possible across docker, k8s-generic, k8s-openshift
    * improve method of determining deployment env so user
      does not have to specify
    * update patched federation templates to support redeployment

-------------------------------
Version 1.0.4, 14 November 2018
-------------------------------

* `ACUMOS-2042: AIO Release 1.0.4 <https://jira.acumos.org/browse/ACUMOS-2042>`_

  * `AIO Release 1.0.4 <https://gerrit.acumos.org/r/#/c/3371/>`_

* `ACUMOS-2018: oneclick_deploy.sh does not pass docker host API check loop <https://jira.acumos.org/browse/ACUMOS-2018>`_

  * `Fix for docker host API check looping forever <https://gerrit.acumos.org/r/#/c/3344/>`_

* `ACUMOS-2009: k8s-deployment.rst contains broken links <https://jira.acumos.org/browse/ACUMOS-2009>`_

  * `Fix broken links <https://gerrit.acumos.org/r/#/c/3333/>`_

------------------------------
Version 1.0.3, 31 October 2018
------------------------------

* `ACUMOS-1984: AIO update to Athena 1.0 final release assembly <https://jira.acumos.org/browse/ACUMOS-1984>`_

  * `AIO update to Athena 1.0 final release assembly <https://gerrit.acumos.org/r/#/c/3298/>`_

------------------------------
Version 1.0.2, 24 October 2018
------------------------------

* `ACUMOS-1930: AIO update to Acumos_1810121300 <https://jira.acumos.org/browse/ACUMOS-1930>`_

  * `Complete docker-engine changes <https://gerrit.acumos.org/r/#/c/3243/>`_
  * `AIO update to Acumos_1810121300 <https://gerrit.acumos.org/r/#/c/3210/>`_

    * AIO update to Acumos_1810121300
    * Also fixes for stabilizing docker-engine service under k8s

------------------------------
Version 1.0.1, 11 October 2018
------------------------------

* `ACUMOS-1894: AIO update to Acumos_1810050030 <https://jira.acumos.org/browse/ACUMOS-1894>`_

  * `AIO update to Acumos_1810050030 <https://gerrit.acumos.org/r/#/c/3159/>`_

-----------------------------
Version 1.0.0, 5 October 2018
-----------------------------

This is the final version as of Release Candidate 0 (RC0).

* `ACUMOS-1784: AIO-0.8: Various bugs in testing private-kubernetes-deploy <https://jira.acumos.org/browse/ACUMOS-1784>`_

  * `Various bugs and other issues needing fixes <https://gerrit.acumos.org/r/#/c/2941/>`_

    * Align with Weekly+Assembly+Acumos_1809291700 with updates:

      * To address `ACUMOS-1831: Create user issue in portal 1.16.0 <https://jira.acumos.org/browse/ACUMOS-1831>`_ : Portal 1.16.1, CDS 1.18.2
      * DS 1.40.1, MSG 1.7.0, kubernetes-client:0.1.3

    * Update onboarding-app version to fix Tosca creation errors
    * Update microservice-generation to latest test version
    * Update probe to latest version
    * add docker-proxy cleanup to clean.sh
    * remove superfluous creation of /var/acumos/docker-proxy/data
    * correct log volume mapping for kubernetes-client
    * fix errors in portal-be templates
    * update BLUEPRINT_ORCHESTRATOR_IMAGE variable
    * update PROTO_VIEWER_IMAGE variable
    * update ACUMOS_BASE_IMAGE variable
    * add kubernetes-client to clean.sh
    * fix iptables rules for docker API access
    * disable error trap when deleting k8s services etc
    * update release notes

------------------------------
Version 0.8, 22 September 2018
------------------------------

This is the final version as of code freeze (M4).

* `Fix reference to microservice-generation API <https://gerrit.acumos.org/r/#/c/2919/>`_

  * `ACUMOS-1768: AIO: add kubernetes-client as of Acumos_1809101130 <https://jira.acumos.org/browse/ACUMOS-1768>`_

* `AIO: add kubernetes-client in Acumos_1809172330 <https://gerrit.acumos.org/r/#/c/2883/>`_

  * `ACUMOS-1768: AIO: add kubernetes-client as of Acumos_1809101130 <https://jira.acumos.org/browse/ACUMOS-1768>`_
  * Update components to Weekly Assembly Acumos_1809172330
  * Add docker-proxy per private-kubernetes-deployment design
  * Add 'restart: on-failure' to docker templates to address timing issues
  * Add extra-hosts spec to docker templates to address inability to resolve
    non-DNS-supported host names

* `Fix docker-cmds startup command <https://gerrit.acumos.org/r/#/c/2824/>`_

  * `ACUMOS-1732: AIO: docker-cmds startup command errors <https://jira.acumos.org/browse/ACUMOS-1732>`_
  * Fix setup_federation error check

* `AIO: Update to assembly Acumos_1808171930 <https://gerrit.acumos.org/r/#/c/2777/>`_

  * `ACUMOS-1715: AIO: Update to assembly Acumos_1808171930 <https://jira.acumos.org/browse/ACUMOS-1715>`_
  * Block host-external access to docker API
  * Add metricbeat-service and ELK stack components

---------------------------
Version 0.7, 24 August 2018
---------------------------

* `Upgrade to CDS 1.16 <https://gerrit.acumos.org/r/#/c/2578/>`_

  * `ACUMOS-1598: AIO support for upgrading or redeploying with existing databases/config <https://jira.acumos.org/browse/ACUMOS-1598>`_
  * Upgrade to Weekly Assembly Acumos_1808041700
  * Assign role "Admin" instead of "admin"

* `Support for redeploy with existing DB <https://gerrit.acumos.org/r/#/c/2570/>`_

  * `ACUMOS-1598: AIO support for upgrading or redeploying with existing databases/config <https://jira.acumos.org/browse/ACUMOS-1598>`_

---------------------------
Version 0.6, 13 August 2018
---------------------------

* `Updates for Chris comments in 2092 <https://gerrit.acumos.org/r/#/c/2360/>`_

  * `ACUMOS-1146: docker or kubernetes as target env for AIO deployment <https://jira.acumos.org/browse/ACUMOS-1146>`_
  * Remove validation-client
  * Add ACUMOS_HTTP_PROXY and ACUMOS_HTTPS_PROXY env vars, add to docker template
  * Fix trailing whitespace
  * Retrieve and customize database script for CDS version
  * Refactor create-user.sh
  * Remove log_level: DEBUG
  * Add nginx vars for azure-client
  * Add upstream_connect/read/send vars to kong APIs
  * Refactor peer-test.sh

* `Baseline for deploy on docker or kubernetes <https://gerrit.acumos.org/r/#/c/2092/>`_

  * `ACUMOS-1146: docker or kubernetes as target env for AIO deployment <https://jira.acumos.org/browse/ACUMOS-1146>`_
  * option for deploy under k8s or docker
  * k8s based deployment
  * docker and nexus under k8s
  * latest components as of Weekly Assembly Acumos_1806281800

* `Use existing docker-ce install <https://gerrit.acumos.org/r/#/c/2064/>`_

  * `ACUMOS-1102: AIO installation with existing dependencies <https://jira.acumos.org/browse/ACUMOS-1102>`_

* `Various updates for deploy to cloud support <https://gerrit.acumos.org/r/#/c/2002/>`_

  * `ACUMOS-982: AIO deploy to cloud fixes <https://jira.acumos.org/browse/ACUMOS-982>`_
  * Update components for Weekly Assembly Acumos_1805241800
  * use user home folder for temp files
  * oneclick_deploy.sh: remove install of linux-image-extra-$(uname -r),
    linux-image-extra-virtual (breaking deployment in AWS)
  * Add nexus user/password variables
  * Map volumes to user home
  * Use docker service names where possible for internal-only APIs

* `Analysis of k8s based Acumos deployment approach <https://gerrit.acumos.org/r/#/c/1940/>`_

  * `ACUMOS-908: Oneclick deploy of Acumos platform under kubernetes <https://jira.acumos.org/browse/ACUMOS-908>`_
  * Add k8s-deployment.rst

------------------------
Version 0.5, 16 May 2018
------------------------

* `Update to current release versions <https://gerrit.acumos.org/r/#/c/1812/>`_

  * `ACUMOS-829: AIO: update to latest releases <https://jira.acumos.org/browse/ACUMOS-829>`_
  * Portal 1.15.16 etc

* `Use expose vs ports where possible <https://gerrit.acumos.org/r/#/c/1774/>`_

  * `ACUMOS-805: AIO: use expose for all service ports as possible <https://jira.acumos.org/browse/ACUMOS-805>`_
  * Update docker-compose templates to use expose vs ports where possible
  * openssl.cnf: add federation-gateway as DND alt-name

* `Fixes in validation testing <https://gerrit.acumos.org/r/#/c/1638/>`_

  * `ACUMOS-700: Implement AIO support for validation <https://jira.acumos.org/browse/ACUMOS-700>`_
  * Update versions to Weekly Assembly Acumos_1805051300
  * Align docker-compose files

--------------------------
Version 0.4, 17 April 2018
--------------------------

* `Fix onboarding issues <https://gerrit.acumos.org/r/#/c/1594/>`_

  * `ACUMOS-656: AIO - fix onboarding issues <https://jira.acumos.org/browse/ACUMOS-656>`_
  * Set onboarding-app http_proxy to null
  * Remove python extra index
  * Upgrade onboarding-app to 1.18.1
  * Split out docker-compose files

* `Post-ONS updates in testing <https://gerrit.acumos.org/r/#/c/1580/>`_

  * `ACUMOS-203 <https://jira.acumos.org/browse/ACUMOS-203>`_
  * Further fixes for kong/CMS testing
  * Align component versions
  * Handle more model onboarding upload errors
  * Handle USER prefixed to container names
  * Enable containers to resolve local DNS hostnames
  * Use domain name for local peer setup
  * Align docker-compose.yml
  * Handle temporary failures in docker login
  * Set subjectAltNames through openssl.cnf
  * Quote models folder to avoid expansion

--------------------------
Version 0.3, 27 March 2018
--------------------------

* `Enhancements for ONS demo <https://gerrit.acumos.org/r/#/c/1497/>`_

  * `ACUMOS-203 <https://jira.acumos.org/browse/ACUMOS-203>`_
  * peer-test.sh: Run commands separately to ensure failures are trapped; Verify
    peers can access federation API at peer
  * align docker-compose templates
  * create-peer.sh: verify federation API is accessible
  * add bootstrap-models.sh
  * acumos-env.sh: update to portal 1.14.48
  * README.md: direct user to docs.acumos.org

* `Updated steps install kong api in docs <https://gerrit.acumos.org/r/#/c/1260/>`_

  * `ACUMOS-351 <https://jira.acumos.org/browse/ACUMOS-351>`_
  * `ACUMOS-409 <https://jira.acumos.org/browse/ACUMOS-409>`_

* `Preliminary updates for federation-gateway <https://gerrit.acumos.org/r/#/c/1307/>`_

  * `ACUMOS-231 <https://jira.acumos.org/browse/ACUMOS-231>`_
  * Preliminary updates for federation-gateway
  * Add peer-test.sh to automate federation test
  * Add setup-peer to automate peer setup
  * Add setup-user to automate user setup
  * Setup "self" federation peer
  * Restart federation-gateway after updating truststore
  * Add openssl.cnf and align certs etc setup with dev/ist
  * Update readme (RST version in a later patch)
  * Update image versions where ready
  * Expose only onboarding and portal-fe via kong proxy
  * Merge kong-migration into kong container
  * Improve cleanup process

--------------------------
Version 0.2, 13 March 2018
--------------------------

* `Remove extra URL path element for onboarding <https://gerrit.acumos.org/r/1288>`_

  * `ACUMOS-231 <https://jira.acumos.org/browse/ACUMOS-231>`_
  * Move nexus under docker-compose.yaml
  * Upgrade to newest docker-ce

* `Various fixes etc for model onboarding <https://gerrit.acumos.org/r/1277>`_

  * `ACUMOS-231 <https://jira.acumos.org/browse/ACUMOS-231>`_
  * Added kong proxy, APIs, server cert, and CA.
  * Use docker-network resolvable names in docker-compose.yaml.
  * Various cleanups in docker-compose.yaml env variable use.
  * Remove extra daemon restart.
  * Fix insecure registries.
  * Remove ports attributes in docker-compose.yaml where possible.
  * clean.sh works without sudo.
  * Fix kong delay method

-------------------------
Version 0.1, 9 March 2018
-------------------------

* `ACUMOS-231 <https://jira.acumos.org/browse/ACUMOS-231>`_

  * `Move nexus under docker-compose.yaml <https://gerrit.acumos.org/r/1229>`_
  * `Use uuidgen instead of apg <https://gerrit.acumos.org/r/1227>`_
  * `WIP: Baseline of all-in-one deploy process <https://gerrit.acumos.org/r/1221>`_
