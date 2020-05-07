# Zero-to-Acumos

> NOTE: This document is a work in progress - subject to change.
>
>> NOTE: z2a should not be used as a production environment deployment tool at this time.  `z2a` is designed for development and/or test environment installations.  Currently, a key component of `z2a` (`kind` -  Kubernetes in Docker) is designed for dev/test environments, not for production workloads.
>>
>> NOTE: Work is being done to split the functionality of `z2a` into two (2) distinct process flows:
>>> The first process flow will perform the complete `z2a` installation including environment creation, VM Operating System preparation, dependency installation, Kubernetes cluster creation and deployment of Acumos noncore and core components. The first process flow is the original (complete) z2a process flow targeting development/test environments where a Kubernetes cluster is build from scratch on a single VM.
>>>
>>> The second process flow will perform the environment creation and the installation of Acumos noncore and core components only. The second process flow is a new z2a process flow targeting pre-build Kubernetes environments.
>>>
>>> In both process flow scenarios, installation of additional Acumos plugins is optional as a follow-on procedure.
>>
>> NOTE: At the time of this writing, the `kind` (Kubernetes in Docker) cluster does not persist across a VM reboot OR a Docker service reconfigure/restart operation. Work to add this cluster recovery capability is being worked on by the upstream developers.  At this time, if (for some reason) the VM is rebooted or the Docker service is restarted, portions of the `z2a` installation process must be executed again and any "work" may be lost.  The end-user must ensure that they have any work performed in the current `z2a` environment saved outside of z2a.
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

* The user **must** have sudo rights on the VM (i.e. must exist in the `/etc/sudoers` file).

* The VM requires Internet access such that OS updates, OS supplemental packages and Helm chart installations can be performed. Either the VM has proxied access to the Internet or the user must be able to configure the proxy setting for the VM.

> NOTE: internet proxy configurations are beyond the scope of the installation documentation.  A very simple proxy mechanism has been provided to assist with the installation process. Proxy configuration HOWTO references have been included in the Additional Documentation section to assist with more complex configuration.

## Deployment (deprecated - to be replaced - see below)

`z2a` performs the Acumos and Acumos plugin(s) installation in a number of discrete steps that are referred to as 'phases'.

* Phase 1 - performs the Linux distribution (RHEL/CentOS or Ubuntu) setup and installation of the tools required to perform the complete installation.  This phase is composed of two (2) shell scripts: `z2a_ph1a.sh` and `z2a_ph1b.sh`.

>NOTE: the user performing the installation MUST log out of their session after the successful completion of Phase 1a and log back in to complete Phase 1 by executing the Phase 1b script.  The logout is required such that the user (installer) can join the `docker` group that is created during Phase 1a and required for Phase 1b and subsequent phases.

* Phase 2 - performs the installation of the Acumos non-core and Acumos core components. This phase is composed of a single shell script: `z2a_ph2.sh`.

> NOTE:  Work is being performed to decouple `z2a` Phase 2 from `z2a` in such a manner that the Phase 2 install and configuration scripts can be ran in environments not created by Phase 1. (i.e. BYOC - Bring Your own Cluster)

* Phase 3 - performs the installation of the Acumos plugin dependencies and Acumos plugins.  Currently, the only Acumos plugin supported in MLWB (Machine Learning WorkBench). This phase is composed of a single shell script: `z2a_ph3.sh`.

> NOTE:  Work is being performed to decouple `z2a` Phase 3 from `z2a` in such a manner that the Phase 3 install and configuration scripts can be ran independently.
>
> NOTE: `z2a` scripts have been developed to run in the phase order noted above.  However, the scripts should be sufficiently portable enough to be ran in a stand-alone manner.

## New Deployment (this section will replace deprecated section above)

`z2a` performs the Acumos and Acumos plugin(s) installation in a number of discrete steps that are referred to as 'phases'.

### Phase 0-kind

Phase `0-kind` consists of three (3) scripts which perform the following tasks:

* End-user environment setup (`0a-env.sh` script)
* Linux distribution (RHEL/CentOS or Ubuntu) setup
* Dependency and OS tools installation (`0b-depends.sh` script)
* Kubernetes cluster creation (`0c-cluster.sh` script)

>NOTE: the user performing the installation MUST log out of their session after the successful completion of `0b-depends.sh` script.  The logout is required such that the user (installer) can join the `docker` group that has just been created.  Upon logging back into a session, the user (installer) will be a member of the `docker` group and can proceed by executing the `0c-cluster.sh` script located in the `~/system-integration/z2a/0-kind` directory.

### Phase 1-acumos

Phase 1-acumos performs the installation of the Acumos non-core and Acumos core components.

> NOTE:  Work is being performed to decouple `z2a` in such a manner that the installation and configuration scripts can be ran in environments not created by Phase `0-kind`. (i.e. BYOC - Bring Your own Cluster)

### Phase 2-plugins

Phase 2-plugins performs the installation of the Acumos plugin dependencies and Acumos plugins.  Currently, the only Acumos plugin supported is MLWB (Machine Learning WorkBench).

> NOTE:  Work is being performed to decouple `z2a` in such a manner that installation and configuration scripts can be ran independently.
>
> NOTE: `z2a` scripts have been developed to run in the phase order noted above.  However, the scripts should be sufficiently portable enough to be ran in a stand-alone manner.

Please refer to the following documents for additional information:

> CONFIG.md   - the Acumos configuration markdown document (in progress)
>
> INSTALL.md  - the Acumos installation markdown document (in progress)

Last Edited: 2020-05-07
