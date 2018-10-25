
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
.. WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
.. See the License for the specific language governing permissions and
.. limitations under the License.
.. ===============LICENSE_END=========================================================

================================

================================
System Integration Release Notes
================================

............................
All-in-One (OneClick Deploy)
............................

------------------------------
Version 1.0.2, 24 October 2018
------------------------------

* `ACUMOS-1930: AIO update to Acumos_1810121300 <https://jira.acumos.org/browse/ACUMOS-1930>`_

  * `Complete docker-engine changes <>'
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

  * `ACUOS-1598: AIO support for upgrading or redeploying with existing databases/config <https://jira.acumos.org/browse/ACUMOS-1598>`_

---------------------------
Version 0.6, 13 August 2018
---------------------------

* `Updates for Chris comments in 2092 <https://gerrit.acumos.org/r/#/c/2360/>`_

  * `ACUMOS-1146: docker or kubernetes as target env for AIO deployment <https://jira.acumos.org/browse/ACUMOS-1146>`_
  * Remove validation-client
  * Add HTTP_PROXY and HTTPS_PROXY env vars, add to docker template
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
  * Remove ports attibutes in docker-compose.yaml where possible.
  * clean.sh works without sudo.
  * Fix kong delay method

-------------------------
Version 0.1, 9 March 2018
-------------------------

* `ACUMOS-231 <https://jira.acumos.org/browse/ACUMOS-231>`_

  * `Move nexus under docker-compose.yaml <https://gerrit.acumos.org/r/1229>`_
  * `Use uuidgen instead of apg <https://gerrit.acumos.org/r/1227>`_
  * `WIP: Baseline of all-in-one deploy process <https://gerrit.acumos.org/r/1221>`_
