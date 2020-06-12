# Zero-to-Acumos

> NOTE: This document is a work in progress - subject to change.
>
> NOTE: Additional wrapper scripts have been developed but require polish/testing.

## What is z2a

`Zero-to-Acumos` (`z2a`) is a collection of Linux shell scripts that have been assembled to perform a simple set of tasks:  install and (where possible) configure Acumos.

`z2a` is composed of two (2) distinct process flows; Flow-1 and Flow-2. In each flow scenarios, installation of additional Acumos plugins is optional as a follow-on procedure.

> NOTE: `z2a` (Flow-1) should not be used as a production environment deployment tool at this time.  `z2a` (Flow-1) has been primarily designed for development and/or test environment installations.  Currently, a key component of `z2a` (Flow-1), `kind` -  Kubernetes in Docker - is not recommended for production installation or production workloads.

In the Acumos `system-integration` repository, the `z2a` sub-directory contains the scripts that perform installation actions based these flows.

### Flow-1

Flow-1 performs a complete `z2a` installation including environment creation, VM Operating System preparation, dependency installation, Kubernetes cluster creation and deployment of Acumos noncore and core components. Flow-1 is based on the original `z2a` process flow targeting development/test environments where a Kubernetes cluster is build from scratch on a single VM.

Flow-1 consists of the following scripts (and descriptions):

```sh
# Step 0[a-c]
z2a/0-kind/0a-env.sh                    # z2a environment creation
z2a/0-kind/0b-depends.sh                # dependency installation and setup
z2a/0-kind/0a-cluster.sh                # Kubernetes ('kind') cluster creation
# Step 1
z2a/1-acumos/1-acumos.sh                # Acumos noncore and core component setup
# Step 2 (optional)
z2a/2-plugins/2-plugins.sh              # Acumos plugins setup (including dependencies)
```

### Flow-2

Flow-2 creates an end-user environment and then performs the installation (and partial configuration) of Acumos noncore and core components. The second process flow is a new `z2a` process flow targeting pre-built Kubernetes cluster environments. (i.e. BYOC - Bring Your Own Cluster)

Flow-2 consists of the following scripts (and descriptions):

```sh
# Step 0
z2a/0-kind/0a-env.sh                    # z2a environment creation
# Step 1
z2a/1-acumos/1-acumos.sh                # Acumos noncore and core component setup
# Step 2 (optional)
z2a/2-plugins/2-plugins.sh              # Acumos plugins setup (including dependencies)
```

## Flow-1 VM Requirements

* At the time of this writing, the Operating System installed on the VM must be either CentOS (v7 or greater) or Ubuntu (18.04 or greater).

> NOTE: earlier versions of CentOS (v6) or Ubuntu (16.04) may be sufficient to run the z2a installation, but they have not been tested.
>
> NOTE: Version 0.8.1 of `kind` provides new cluster recovery capabilities.  `kind` v0.8.1 requires that the VM used be Ubuntu 20.04 or Centos 8 to operate properly.

* VM Resource Sizing Recommendations
  * four (4) vCPU (minimum)
  * 32GB of memory (minimum)
  * 30GB disk space (minimum) (40GB+ for MLWB)
  * additional disk space for models (based on developer requirements)

* VM Distribution Recommendations
  * git (source code tool)
    * git is not installed by default by Linux distributions
    * git must be installed to allow for Acumos repo replication

### Miscellaneous Requirements

* A SSH client with port-forward/tunnel/proxy capabilities
  * PuTTY (Windows SSH client)
  * SecureCRT (MacOS SSH client)

* For Flow-1 installation, the user **must** have sudo rights on the VM (i.e. must exist in the `/etc/sudoers` file).

* For Flow-1, the VM requires Internet access such that OS updates, OS supplemental packages and Helm chart installations can be performed. Either the VM has proxied access to the Internet or the user must be able to configure the proxy setting for the VM.

> NOTE: internet proxy configurations are beyond the scope of the installation documentation.  `z2a` provides a simple proxy mechanism has been provided to assist with the installation process. Proxy configuration HOWTO references have been included in the Additional Documentation section to assist with more complex configuration.

## Flow-1 Deployment

Flow One (Flow-1) performs a complete `z2a` Acumos installation including environment creation, VM Operating System preparation, dependency installation, Kubernetes cluster creation and deployment of Acumos noncore and core components. Flow-1 is based on the original `z2a` process flow targeting development/test environments where a Kubernetes cluster is build from scratch on a single VM.

### Steps 0[a-c]-*

In the directory `z2a/0-kind` there are three (3) scripts which perform the following tasks:

* End-user environment setup (`0a-env.sh` script)
  * Linux distribution (RHEL/CentOS or Ubuntu) setup
* Dependency and OS tools installation (`0b-depends.sh` script)
* Kubernetes cluster creation (`0c-cluster.sh` script)

> NOTE: Execution of the `z2a/0-kind/0a-env.sh` script is required for both Flow-1 (vanilla VM) installation and Flow-2 (pre-built Kubernetes cluster) installation.  The `z2a/0-kind/0a-env.sh` script creates and populates environment variables necessary for proper operation of subsequent scripts.
>
>NOTE: For 1st time users, the user performing the installation MUST log out of their session after the successful completion of `z2a/0-kind/0b-depends.sh` script.  The logout is required such that the user (installer) can join the `docker` group that has just been created.  Upon logging back into a session, the user (installer) will be a member of the `docker` group and can proceed by executing the `0c-cluster.sh` script located in the `~/system-integration/z2a/0-kind` directory.  Any subsequent re-run of the `z2a/0-kind/0b-depends.sh` script does not require the user to log out (one time requirement).

### Step 1-acumos

> NOTE: Execution of the `z2a/0-kind/0a-env.sh` script is required for both Flow-1 (vanilla VM) installation and Flow-2 (pre-built Kubernetes cluster) installation.  The `z2a/0-kind/0a-env.sh` script creates and populates environment variables necessary for proper operation of subsequent scripts.

In the directory `z2a/1-acumos` there is a single (1) script which performs:

* the installation of the Acumos non-core components (`1-acumos.sh` script)
* the installation of the Acumos core components (`1-acumos.sh` script)

### Step 2-plugins

> NOTE: Execution of the `z2a/0-kind/0a-env.sh` script is required for both Flow-1 (vanilla VM) installation and Flow-2 (pre-built Kubernetes cluster) installation.  The `z2a/0-kind/0a-env.sh` script creates and populates environment variables necessary for proper operation of subsequent scripts.

In the directory `z2a/2-plugins` there is a single (1) script which performs:

* the installation of the Acumos plugin dependencies (`2-plugins.sh` script)
* the installation of the Acumos plugins (`2-plugins.sh` script)

Currently, the only Acumos plugin supported is MLWB (Machine Learning WorkBench).

## Known Issues

ISSUE: At the time of this writing, the `kind` (Kubernetes in Docker) cluster does not persist across a VM reboot OR a Docker service reconfigure/restart operation. Development activities to add this cluster recovery capability are being performed by the upstream developers.  At this time, if (for some reason) the VM is rebooted or the Docker service is restarted, portions of the `z2a` installation process must be executed again and any "work" may be lost.  End-users must ensure that they have any work performed in the current `z2a` environment saved outside of z2a.

> NOTE: Version 0.8.1 of `kind` provides new cluster recovery capabilities.  `kind` v0.8.1 requires that the VM used be Ubuntu 20.04 or Centos 8 to operate properly.

ISSUE: `z2a` performs minimal post-installation component configuration.  The `z2a` scripts perform a complete installation of Acumos and where automation can be applied, automated configuration is performed. As `z2a` matures, additional post-installation configuration will be added to configurations that can be easily maintained.

At this time, automated configuration of only the following components is being performed:

* MariaDB (for Common Data Services)
* Sonatype Nexus
* Kong (and PostgreSQL)
  * Note: Kong has been deprecated. To be replaced with native k8s ingress w/ Nginx.

## Addendum

Please refer to the following documents for additional information:

> CONFIG.md   - the Acumos configuration markdown document (in progress)
>
> INSTALL.md  - the Acumos installation markdown document (in progress)

Last Edited: 2020-06-09
