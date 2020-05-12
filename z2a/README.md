# Zero-to-Acumos

> NOTE: This document is a work in progress - subject to change.
>
>> NOTE: z2a should not be used as a production environment deployment tool at this time.  `z2a` has been primarily designed for development and/or test environment installations.  Currently, a key component of `z2a` (`kind` -  Kubernetes in Docker) is not recommended for production installation or production workloads.
>>
>> NOTE: Work is being done to split the functionality of `z2a` into two (2) distinct process flows:
>>> The first process flow (Flow 1) will perform the complete `z2a` installation including environment creation, VM Operating System preparation, dependency installation, Kubernetes cluster creation and deployment of Acumos noncore and core components. The first process flow is the original (complete) z2a process flow targeting development/test environments where a Kubernetes cluster is build from scratch on a single VM.
>>>
>>> The second process flow (Flow 2) will perform the environment creation and the installation of Acumos noncore and core components only. The second process flow is a new z2a process flow targeting pre-build Kubernetes cluster environments.
>>>
>>> In both process flow scenarios, installation of additional Acumos plugins is optional as a follow-on procedure.
>>
>> NOTE: At the time of this writing, the `kind` (Kubernetes in Docker) cluster does not persist across a VM reboot OR a Docker service reconfigure/restart operation. Development activities to add this cluster recovery capability is being performed by the upstream developers.  At this time, if (for some reason) the VM is rebooted or the Docker service is restarted, portions of the `z2a` installation process must be executed again and any "work" may be lost.  End-users must ensure that they have any work performed in the current `z2a` environment saved outside of z2a.
>>
>> NOTE: `z2a` performs minimal post-installation component configuration.  The `z2a` scripts perform a complete installation of Acumos and where automation can be applied, automated configuration is performed. As `z2a` matures, additional post-installation configuration will be added to configurations that can be easily maintained.
>>
>>At this time, automated configuration of the following components is being performed:
>>
>>* MariaDB (for Common Data Services)
>>* Sonatype Nexus
>>* Kong (and PostgreSQL)

In the Acumos `system-integration` repository, the `z2a` sub-directory contains scripts that will allow for installation of Acumos on a vanilla Linux distribution.

`z2a` is intended to be a simple installation mechanism for Acumos to allow developers to get up and running with Acumos as quickly as possible.  In the future, additional functionality may be added. `z2a` is not based on `AIO` (All-in-One) and `z2a` is not meant to replace the more advanced functionality of `AIO`.

## How z2a and AIO differ and are similar

* `z2a` performs Acumos installation on Kubernetes only ; `AIO` performs multiple life-cycle management functions (installation, configuration, removal and updates) of Acumos components across a number of installation scenarios
* `z2a` performs an Acumos installation for K8s environments only (using Helm charts) only ; `AIO` performs actions (noted above) for Docker, Kubernetes and OpenShift environments
* `z2a` attempts to provide a very simple install mechanism for people with no Acumos knowledge; `AIO` usage requires more advanced knowledge of the Acumos installation environment

## VM Requirements

* At the time of this writing, the Operating System installed on the VM must be either CentOS (v7 or greater) or Ubuntu (18.04 or greater).

> NOTE: earlier versions of CentOS (v6) or Ubuntu (16.04) may be sufficient to run the z2a installation, but they have not been tested.

* VM Sizing Recommendations
  * four (4) vCPU (minimum)
  * 32GB of memory (minimum)
  * 30GB disk space (minimum) (40GB+ for MLWB)

## Miscellaneous Requirements

* A SSH client with port-forward/tunnel/proxy capabilities
  * PuTTY (Windows SSH client)
  * SecureCRT (MacOS SSH client)

* The user **must** have sudo rights on the VM (i.e. must exist in the `/etc/sudoers` file).

* The VM requires Internet access such that OS updates, OS supplemental packages and Helm chart installations can be performed. Either the VM has proxied access to the Internet or the user must be able to configure the proxy setting for the VM.

> NOTE: internet proxy configurations are beyond the scope of the installation documentation.  A very simple proxy mechanism has been provided to assist with the installation process. Proxy configuration HOWTO references have been included in the Additional Documentation section to assist with more complex configuration.

## Deployment

`z2a` performs the Acumos and Acumos plugin(s) installation in a number of discrete steps that are referred to as 'phases'.

### Phase 0-kind

Phase `0-kind` consists of three (3) scripts which perform the following tasks:

* End-user environment setup (`0a-env.sh` script)
  * Linux distribution (RHEL/CentOS or Ubuntu) setup
* Dependency and OS tools installation (`0b-depends.sh` script)
* Kubernetes cluster creation (`0c-cluster.sh` script)

> NOTE: Execution of the `0a-env.sh` script is required for both Flow 1 (vanilla VM) installation and Flow 2 (pre-built Kubernetes cluster) installation.  The `0a-env.sh` script creates and populates environment variables necessary for proper operation of subsequent scripts.

>NOTE: For 1st time users, the user performing the installation MUST log out of their session after the successful completion of `0b-depends.sh` script.  The logout is required such that the user (installer) can join the `docker` group that has just been created.  Upon logging back into a session, the user (installer) will be a member of the `docker` group and can proceed by executing the `0c-cluster.sh` script located in the `~/system-integration/z2a/0-kind` directory.  Any subsequent re-run of the `0b-depends.sh` script does not require the user to log out (one time requirement).

### Phase 1-acumos

> NOTE: Execution of the `0a-env.sh` script is required for both Flow 1 (vanilla VM) installation and Flow 2 (pre-built Kubernetes cluster) installation.  The `0a-env.sh` script creates and populates environment variables necessary for proper operation of subsequent scripts.

Phase `1-acumos` consists of a single (1) script which performs:

* the installation of the Acumos non-core components (`1-acumos.sh` script)
* the installation of the Acumos core components (`1-acumos.sh` script)

### Phase 2-plugins

> NOTE: Execution of the `0a-env.sh` script is required for both Flow 1 (vanilla VM) installation and Flow 2 (pre-built Kubernetes cluster) installation.  The `0a-env.sh` script creates and populates environment variables necessary for proper operation of subsequent scripts.

Phase `2-plugins` consists fof a single (1) script which performs:

* the installation of the Acumos plugin dependencies (`2-plugins.sh` script)
* the installation of the Acumos plugins (`2-plugins.sh` script)

Currently, the only Acumos plugin supported is MLWB (Machine Learning WorkBench).

## Addendum

Please refer to the following documents for additional information:

> CONFIG.md   - the Acumos configuration markdown document (in progress)
>
> INSTALL.md  - the Acumos installation markdown document (in progress)

Last Edited: 2020-05-12