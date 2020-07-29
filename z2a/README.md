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

# Zero-to-Acumos README

>NOTE: Work in progress - subject to change.

In the Acumos `system-integration` repository, the `z2a` sub-directory contains the scripts that perform installation actions based the flows described below.

## Flow-1

Flow-1 consists of three (3) steps using the following scripts (and descriptions):

```bash
# Step 0[a-c]
z2a/0-kind/0a-env.sh                    # z2a environment creation
z2a/0-kind/0b-depends.sh                # dependency installation and setup
z2a/0-kind/0a-cluster.sh                # Kubernetes ('kind') cluster creation
# Step 1
z2a/1-acumos/1-acumos.sh                # Acumos noncore and core component setup
# Step 2 (optional)
z2a/2-plugins/2-plugins.sh              # Acumos plugins setup (including dependencies)
```

> NOTE: In Flow-1, the `z2a` environment creation script (01-env.sh) will have to be executed during the initial setup and again after logging out and logging back into the new session.

## Flow-1 VM Requirements

* At the time of this writing, the Operating System installed on the VM must be either RedHat/CentOS (v7 or greater, v8 recommended) or Ubuntu (18.04 or greater, 20.04 recommended).

>NOTE: earlier versions of RedHat/CentOS (v6) or Ubuntu (16.04) may be sufficient to run the z2a installation, but they have not been tested.
>
>NOTE: Version 0.8.1 of `kind` provides new cluster recovery capabilities.  `kind` v0.8.1 requires that the VM used be Ubuntu 20.04 or Centos 8 to operate properly.

* Flow-1 VM Resource Sizing Recommendations
  * four (4) vCPU (minimum)
  * 32GB of memory (minimum)
  * 60GB disk space (minimum) (~100GB+ for MLWB and other plugins)
  * additional disk space for models (based on developer requirements)

* VM Distribution Recommendations
  * git (source code tool)
    * git is not installed by default by Linux distributions
    * git must be installed to allow for Acumos repository replication

### Miscellaneous Requirements

* A SSH client with port-forward/tunnel/proxy capabilities; such as:
  * PuTTY (Windows SSH client)
  * SecureCRT (MacOS SSH client)
  * OpenSSH (Linux SSH client)

* For Flow-1 installation, the user **must** have sudo rights on the VM (i.e. must exist in the `/etc/sudoers` file).

* For Flow-1, the VM requires Internet access such that OS updates, OS supplemental packages and Helm chart installations can be performed. Either the VM has proxied access to the Internet or the user must be able to configure the proxy setting for the VM.

>NOTE: internet proxy configurations are beyond the scope of the installation documentation.  Please see the README-PROXY.md document for assistance with proxy configurations requirements.

## Flow-1 Deployment

Flow One (Flow-1) performs a complete `z2a` Acumos installation including environment creation, VM Operating System preparation, dependency installation, Kubernetes cluster creation and deployment of Acumos noncore and core components. Flow-1 is based on the original `z2a` process flow targeting development/test environments where a Kubernetes cluster is build from scratch on a single VM.

### Flow 1 - Steps 0[a-c]-*

In the directory `z2a/0-kind` there are three (3) scripts which perform the following tasks:

* End-user environment setup (`0a-env.sh` script)
  * Linux distribution (RHEL/CentOS or Ubuntu) setup
* Dependency and OS tools installation (`0b-depends.sh` script)
* Kubernetes cluster creation (`0c-cluster.sh` script)

>NOTE: Execution of the `z2a/0-kind/0a-env.sh` script creates and populates environment variables necessary for proper operation of subsequent scripts.
>
>NOTE: For 1st time users, the user performing the installation MUST log out of their session after the successful completion of `z2a/0-kind/0b-depends.sh` script.  The logout is required such that the user (installer) can join the `docker` group that has just been created.
>
>Upon logging back into a session, the user (installer) will be a member of the `docker` group and can proceed by re-executing the `0a-env.sh` script and then the `0c-cluster.sh` script located in the `~/system-integration/z2a/0-kind` directory.  Any subsequent re-run of the `z2a/0-kind/0b-depends.sh` script does not require the user to log out (one time requirement).

### Flow 1 - Step 1-acumos

In the directory `z2a/1-acumos` there is a single (1) script which performs:

* the installation of the Acumos non-core components (`1-acumos.sh` script)
* the installation of the Acumos core components (`1-acumos.sh` script)

### Flow 1 - Step 2-plugins

In the directory `z2a/2-plugins` there is a single (1) script which performs:

* the installation of the Acumos plugin dependencies (`2-plugins.sh` script)
* the installation of the Acumos plugins (`2-plugins.sh` script)

Currently, the only Acumos plugin supported is MLWB (Machine Learning WorkBench).

## Flow-2

Flow-2 consists of three (3) steps using the following scripts (and descriptions):

```bash
# Step 0
z2a/0-kind/0a-env.sh                    # z2a environment creation
# Step 1
z2a/1-acumos/1-acumos.sh                # Acumos noncore and core component setup
# Step 2 (optional)
z2a/2-plugins/2-plugins.sh              # Acumos plugins setup (including dependencies)
```

## Flow-2 Deployment

Flow Two (Flow-2) performs a `z2a` Acumos installation including environment creation and deployment of Acumos noncore and core components. Flow-2 is based on the original `z2a` process flow, but is targeted at Acumos installations onto a Kubernetes cluster that is already built and ready for application installation.

### Flow 2 - Step 0a

In the directory `z2a/0-kind` there is one (3) script which perform the following task:

* End-user environment setup (`0a-env.sh` script)

>NOTE: Execution of the `z2a/0-kind/0a-env.sh` script creates and populates environment variables necessary for proper operation of subsequent scripts.

### Flow 2 - Step 1-acumos

In the directory `z2a/1-acumos` there is a single (1) script which performs:

* the installation of the Acumos non-core components (`1-acumos.sh` script)
* the installation of the Acumos core components (`1-acumos.sh` script)

### Flow 2 - Step 2-plugins

In the directory `z2a/2-plugins` there is a single (1) script which performs:

* the installation of the Acumos plugin dependencies (`2-plugins.sh` script)
* the installation of the Acumos plugins (`2-plugins.sh` script)

Currently, the only Acumos plugin supported is MLWB (Machine Learning WorkBench).

-----

## Known Issues

ISSUE: At the time of this writing, the `kind` (Kubernetes in Docker) cluster does not persist across a VM reboot OR a Docker service reconfigure/restart operation. Development activities to add this cluster recovery capability are being performed by the upstream developers.  At this time, if (for some reason) the VM is rebooted or the Docker service is restarted, portions of the `z2a` installation process must be executed again and any "work" may be lost.  End-users must ensure that they have any work performed in the current `z2a` environment saved outside of z2a.

>NOTE: Version 0.8.1 of `kind` provides new cluster recovery capabilities.  `kind` v0.8.1 requires Ubuntu 20.04 or Centos 7/8 to install correctly and operate properly.

ISSUE: `z2a` performs post-installation component configuration.  The `z2a` scripts perform a complete installation of Acumos and where automation can be applied, automated configuration is performed. As `z2a` matures, additional post-installation configuration will be added to configurations that can be easily maintained.

At this time, automated configuration of only the following components is being performed:

* MariaDB (for Common Data Services)
* Sonatype Nexus
* Kong (and PostgreSQL)
  * Note: Kong has been deprecated. Replaced with native k8s ingress w/ Nginx.
* Nginx (for k8s ingress and native service proxies)

```bash
// Created: 2020/03/20
// Last modified: 2020/07/09
```
